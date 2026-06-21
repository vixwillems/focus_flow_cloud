#import <Foundation/Foundation.h>
#import <stdint.h>
#import <stdbool.h>

NS_ASSUME_NONNULL_BEGIN

// Forward-declare the Swift class so we don't need to import the auto-generated
// Swift header (which is more brittle and slower to compile). The class is
// declared @objc(FFLiveActivity) so the Obj-C runtime name is stable.
@class FFLiveActivity;

@interface FFLiveActivityBridge : NSObject
+ (FFLiveActivity * _Nullable)shared;
@end

NS_ASSUME_NONNULL_END

extern "C" {

// `visibility("default")` on the declaration + `__attribute__((used))` on the
// definition (in FFLiveActivityBridge.mm) is what actually keeps the symbols
// in the release binary. The previous `-Wl,-u,_ff_live_activity_*` OTHER_LDFLAGS
// was the wrong flag for that job: `-u,` forces symbol resolution from static
// libraries, it does NOT prevent DEAD_CODE_STRIPPING. With both attributes
// applied, dlsym(RTLD_DEFAULT, "ff_live_activity_*") resolves correctly and
// the in-app "diagnostics" surface stops reporting "symbol not found".
#define FF_LIVE_ACTIVITY_EXPORT __attribute__((visibility("default")))

FF_LIVE_ACTIVITY_EXPORT bool ff_live_activity_is_available(void);
FF_LIVE_ACTIVITY_EXPORT bool ff_live_activity_is_enabled(void);
FF_LIVE_ACTIVITY_EXPORT void ff_live_activity_set_enabled(bool enabled);
FF_LIVE_ACTIVITY_EXPORT bool ff_live_activity_start(
    const char * _Nonnull session_id,
    const char * _Nonnull phase,
    int32_t total_seconds,
    const char * _Nullable task_name
);
FF_LIVE_ACTIVITY_EXPORT bool ff_live_activity_update(
    int32_t seconds_remaining,
    bool is_paused,
    const char * _Nonnull phase,
    const char * _Nullable task_name
);
FF_LIVE_ACTIVITY_EXPORT bool ff_live_activity_end(void);
FF_LIVE_ACTIVITY_EXPORT void ff_live_activity_end_all(void);

FF_LIVE_ACTIVITY_EXPORT void ff_live_activity_did_foreground(void);

FF_LIVE_ACTIVITY_EXPORT void ff_write_diagnostics(const char * _Nonnull blob);
FF_LIVE_ACTIVITY_EXPORT const char * _Nullable ff_live_activity_read_diagnostics(void);

}
