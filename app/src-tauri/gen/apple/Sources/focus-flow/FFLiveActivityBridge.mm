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

@implementation FFLiveActivityBridge
+ (FFLiveActivity * _Nullable)shared {
    return (FFLiveActivity *)FFLAC_Shared();
}
@end

extern "C" {

bool ff_live_activity_is_available(void) {
    id shared = FFLAC_Shared();
    if (shared == nil) return false;
    SEL sel = NSSelectorFromString(@"isAvailable");
    if (![shared respondsToSelector:sel]) return false;
    BOOL (*msg)(id, SEL) = (BOOL (*)(id, SEL))objc_msgSend;
    return msg(shared, sel);
}

bool ff_live_activity_is_enabled(void) {
    id shared = FFLAC_Shared();
    if (shared == nil) return false;
    SEL sel = NSSelectorFromString(@"isEnabled");
    if (![shared respondsToSelector:sel]) return false;
    BOOL (*msg)(id, SEL) = (BOOL (*)(id, SEL))objc_msgSend;
    return msg(shared, sel);
}

void ff_live_activity_set_enabled(bool enabled) {
    id shared = FFLAC_Shared();
    if (shared == nil) return;
    SEL sel = NSSelectorFromString(@"setEnabled:");
    if (![shared respondsToSelector:sel]) return;
    void (*msg)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))objc_msgSend;
    msg(shared, sel, enabled ? YES : NO);
}

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
    return msg(shared, sel, sidStr, phaseStr, total_seconds, (taskStr ?: (NSString *)[NSNull null]));
}

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
    return msg(shared, sel, seconds_remaining, is_paused ? YES : NO, phaseStr, (taskStr ?: (NSString *)[NSNull null]));
}

bool ff_live_activity_end(void) {
    id shared = FFLAC_Shared();
    if (shared == NULL) return false;
    SEL sel = NSSelectorFromString(@"endActivity");
    if (![shared respondsToSelector:sel]) return false;
    BOOL (*msg)(id, SEL) = (BOOL (*)(id, SEL))objc_msgSend;
    return msg(shared, sel);
}

void ff_live_activity_end_all(void) {
    id shared = FFLAC_Shared();
    if (shared == NULL) return;
    SEL sel = NSSelectorFromString(@"endAllActivities");
    if (![shared respondsToSelector:sel]) return;
    void (*msg)(id, SEL) = (void (*)(id, SEL))objc_msgSend;
    msg(shared, sel);
}

}
