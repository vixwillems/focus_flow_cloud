#import "FFLiveActivityBridge.h"
#import <objc/runtime.h>
#import <objc/message.h>

// The Swift class is declared @objc(FFLiveActivity) with `shared` as a class
// property (NSObject). We look it up dynamically so the .mm file does not need
// to import the auto-generated `FocusFlow-Swift.h` header (which would slow
// down incremental builds and require the Swift compiler to have already
// emitted that header at compile time of this TU).

static Class FFLAC_Class(void) {
    static Class cls = NULL;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cls = NSClassFromString(@"FFLiveActivity");
        if (cls == NULL) {
            // Fallback: try the mangled Swift name (e.g. "FocusFlow.FFLiveActivity")
            NSString *mangled = [@"FocusFlow." stringByAppendingString:@"FFLiveActivity"];
            cls = NSClassFromString(mangled);
        }
    });
    return cls;
}

static id FFLAC_Shared(void) {
    Class cls = FFLAC_Class();
    if (cls == NULL) return nil;
    SEL sharedSel = NSSelectorFromString(@"shared");
    if (![cls respondsToSelector:sharedSel]) return nil;
    return ((id (*)(id, SEL))objc_msgSend)(cls, sharedSel);
}

static NSString * _Nullable FFLAC_Str(const char * s) {
    if (s == NULL) return nil;
    NSString *str = [NSString stringWithUTF8String:s];
    if (str == nil || [str length] == 0) return nil;
    return str;
}

// Mirror of SharedStorage.writeDiagnostics — duplicates the call from C so
// the .mm side can write diagnostics too without needing a Swift callback.
// (We cannot use SharedStorage directly from .mm because it's a Swift enum
// with a static method, which would force us to import the auto-generated
// FocusFlow-Swift.h header.)
static void FFLAC_WriteDiagnostics(NSString * _Nonnull blob) {
    NSString *suite = @"group.com.francescopio.focusflow";
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suite];
    [defaults setObject:blob forKey:@"ff.diagnostics"];
}

@implementation FFLiveActivityBridge
+ (FFLiveActivity * _Nullable)shared {
    return (FFLiveActivity *)FFLAC_Shared();
}
@end

extern "C" {

__attribute__((visibility("default"), used))
void ff_write_diagnostics(const char * blob) {
    if (blob == NULL) return;
    NSString *str = [NSString stringWithUTF8String:blob];
    if (str == nil) return;
    FFLAC_WriteDiagnostics(str);
}

// Returns a heap-allocated C string. The Rust side reads it with CStr
// and copies it. Caller must not free — we use a static buffer to
// avoid lifetime issues across the FFI boundary.
static char kDiagBuffer[2048] = {0};
__attribute__((visibility("default"), used))
const char * ff_live_activity_read_diagnostics(void) {
    NSString *suite = @"group.com.francescopio.focusflow";
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suite];
    NSString *blob = [defaults stringForKey:@"ff.diagnostics"];
    if (blob == nil) {
        snprintf(kDiagBuffer, sizeof(kDiagBuffer), "no diagnostic written yet");
    } else {
        snprintf(kDiagBuffer, sizeof(kDiagBuffer), "%s", [blob UTF8String]);
    }
    return kDiagBuffer;
}

__attribute__((visibility("default"), used))
bool ff_live_activity_is_available(void) {
    Class cls = FFLAC_Class();
    if (cls == NULL) {
        FFLAC_WriteDiagnostics(@"ff_live_activity_is_available: FFLiveActivity class not found (NSClassFromString returned nil)");
        return false;
    }
    id shared = FFLAC_Shared();
    if (shared == nil) {
        FFLAC_WriteDiagnostics(@"ff_live_activity_is_available: +shared returned nil (class found, but instance is nil)");
        return false;
    }
    SEL sel = NSSelectorFromString(@"isAvailable");
    if (![shared respondsToSelector:sel]) {
        FFLAC_WriteDiagnostics(@"ff_live_activity_is_available: -isAvailable selector not found (class+shared found, but doesn't respond to isAvailable)");
        return false;
    }
    BOOL (*msg)(id, SEL) = (BOOL (*)(id, SEL))objc_msgSend;
    BOOL result = msg(shared, sel);
    // The Swift side will overwrite this with a richer diagnostic.
    FFLAC_WriteDiagnostics([NSString stringWithFormat:@"ff_live_activity_is_available: C function returned %d (Swift may overwrite)", result]);
    return result;
}

__attribute__((visibility("default"), used))
bool ff_live_activity_is_enabled(void) {
    id shared = FFLAC_Shared();
    if (shared == nil) return false;
    SEL sel = NSSelectorFromString(@"isEnabled");
    if (![shared respondsToSelector:sel]) return false;
    BOOL (*msg)(id, SEL) = (BOOL (*)(id, SEL))objc_msgSend;
    return msg(shared, sel);
}

__attribute__((visibility("default"), used))
void ff_live_activity_set_enabled(bool enabled) {
    id shared = FFLAC_Shared();
    if (shared == nil) return;
    SEL sel = NSSelectorFromString(@"setEnabled:");
    if (![shared respondsToSelector:sel]) return;
    void (*msg)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))objc_msgSend;
    msg(shared, sel, enabled ? YES : NO);
}

__attribute__((visibility("default"), used))
bool ff_live_activity_start(const char * session_id, const char * phase, int32_t total_seconds, const char * _Nullable task_name) {
    id shared = FFLAC_Shared();
    if (shared == NULL) return false;

    NSString *sidStr = FFLAC_Str(session_id);
    NSString *phaseStr = FFLAC_Str(phase);
    NSString *taskStr = FFLAC_Str(task_name);
    if (sidStr == NULL || phaseStr == NULL) return false;

    SEL sel = NSSelectorFromString(@"startActivityWithSessionId:phaseRaw:totalSeconds:taskName:");
    if (![shared respondsToSelector:sel]) return false;

    BOOL (*msg)(id, SEL, NSString *, NSString *, int32_t, NSString *) =
        (BOOL (*)(id, SEL, NSString *, NSString *, int32_t, NSString *))objc_msgSend;
    // Pass `taskStr` directly (may be nil). Do NOT fall back to [NSNull null] —
    // Swift's Obj-C bridge for `String?` expects nil, and NSNull is not an
    // NSString, which would crash when Swift tries to bridge the value.
    return msg(shared, sel, sidStr, phaseStr, total_seconds, taskStr);
}

__attribute__((visibility("default"), used))
bool ff_live_activity_update(int32_t seconds_remaining, bool is_paused, const char * phase, const char * _Nullable task_name) {
    id shared = FFLAC_Shared();
    if (shared == NULL) return false;

    NSString *phaseStr = FFLAC_Str(phase);
    NSString *taskStr = FFLAC_Str(task_name);
    if (phaseStr == NULL) return false;

    SEL sel = NSSelectorFromString(@"updateActivityWithSecondsRemaining:isPaused:phaseRaw:taskName:");
    if (![shared respondsToSelector:sel]) return false;

    BOOL (*msg)(id, SEL, int32_t, BOOL, NSString *, NSString *) =
        (BOOL (*)(id, SEL, int32_t, BOOL, NSString *, NSString *))objc_msgSend;
    // See comment in ff_live_activity_start: pass nil, never [NSNull null].
    return msg(shared, sel, seconds_remaining, is_paused ? YES : NO, phaseStr, taskStr);
}

__attribute__((visibility("default"), used))
bool ff_live_activity_end(void) {
    id shared = FFLAC_Shared();
    if (shared == NULL) return false;
    SEL sel = NSSelectorFromString(@"endActivity");
    if (![shared respondsToSelector:sel]) return false;
    BOOL (*msg)(id, SEL) = (BOOL (*)(id, SEL))objc_msgSend;
    return msg(shared, sel);
}

__attribute__((visibility("default"), used))
void ff_live_activity_end_all(void) {
    id shared = FFLAC_Shared();
    if (shared == NULL) return;
    SEL sel = NSSelectorFromString(@"endAllActivities");
    if (![shared respondsToSelector:sel]) return;
    void (*msg)(id, SEL) = (void (*)(id, SEL))objc_msgSend;
    msg(shared, sel);
}

__attribute__((visibility("default"), used))
void ff_live_activity_did_foreground(void) {
    id shared = FFLAC_Shared();
    if (shared == NULL) {
        FFLAC_WriteDiagnostics(@"ff_live_activity_did_foreground: shared is nil");
        return;
    }
    SEL sel = NSSelectorFromString(@"didForeground");
    if (![shared respondsToSelector:sel]) {
        FFLAC_WriteDiagnostics(@"ff_live_activity_did_foreground: selector not found");
        return;
    }
    void (*msg)(id, SEL) = (void (*)(id, SEL))objc_msgSend;
    msg(shared, sel);
}

}
