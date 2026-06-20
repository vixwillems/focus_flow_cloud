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

bool ff_live_activity_is_available(void);
bool ff_live_activity_is_enabled(void);
void ff_live_activity_set_enabled(bool enabled);
bool ff_live_activity_start(
    const char * _Nonnull session_id,
    const char * _Nonnull phase,
    int32_t total_seconds,
    const char * _Nullable task_name
);
bool ff_live_activity_update(
    int32_t seconds_remaining,
    bool is_paused,
    const char * _Nonnull phase,
    const char * _Nullable task_name
);
bool ff_live_activity_end(void);
void ff_live_activity_end_all(void);

void ff_write_diagnostics(const char * _Nonnull blob);
const char * _Nullable ff_live_activity_read_diagnostics(void);

}
