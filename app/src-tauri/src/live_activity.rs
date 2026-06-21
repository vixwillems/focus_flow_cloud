// Live Activity / Dynamic Island / Widget bridge for iOS.
//
// The Rust crate is built first (via `cargo build`) as a staticlib + cdylib.
// At that time, the Swift/Obj-C++ symbols (FFLiveActivityBridge.mm) do not
// yet exist — they're compiled and linked later by Xcode when the iOS app
// target is built. So we cannot use plain `extern "C"` declarations: the
// Rust linker would fail with "undefined symbols" before Xcode has a chance
// to provide them.
//
// Instead, we look up the symbols at runtime via `dlsym` on the main
// executable (the iOS app binary). This works because:
//   1. The iOS app binary is the main executable (not a dylib loaded by it).
//   2. `dlsym(RTLD_DEFAULT, "ff_live_activity_*")` resolves symbols in the
//      main executable as well as all loaded dylibs. `RTLD_DEFAULT` is
//      `((void *) -2)` on Apple — see `dlsym()` below for why NULL is wrong.
//   3. By the time any of our Tauri commands run, the iOS app is fully
//      loaded, so the symbols are present.
//
// On non-iOS platforms the runtime lookup always returns null and the
// Tauri commands are no-ops.

use std::ffi::{c_char, c_int, c_void, CString};

#[cfg(target_os = "ios")]
type FnIsAvailable = unsafe extern "C" fn() -> bool;
#[cfg(target_os = "ios")]
type FnIsEnabled = unsafe extern "C" fn() -> bool;
#[cfg(target_os = "ios")]
type FnSetEnabled = unsafe extern "C" fn(bool);
#[cfg(target_os = "ios")]
type FnStart =
    unsafe extern "C" fn(*const c_char, *const c_char, c_int, *const c_char, c_int, c_int) -> bool;
#[cfg(target_os = "ios")]
type FnUpdate =
    unsafe extern "C" fn(c_int, bool, *const c_char, *const c_char, c_int, c_int) -> bool;
#[cfg(target_os = "ios")]
type FnEnd = unsafe extern "C" fn() -> bool;
#[cfg(target_os = "ios")]
type FnEndAll = unsafe extern "C" fn();
#[cfg(target_os = "ios")]
type FnDidForeground = unsafe extern "C" fn();
#[cfg(target_os = "ios")]
type FnReadDiagnostics = unsafe extern "C" fn() -> *const c_char;

#[cfg(target_os = "ios")]
mod loader {
    use super::*;
    use std::sync::OnceLock;

    pub struct LiveActivityFns {
        pub is_available: Option<FnIsAvailable>,
        pub is_enabled: Option<FnIsEnabled>,
        pub set_enabled: Option<FnSetEnabled>,
        pub start: Option<FnStart>,
        pub update: Option<FnUpdate>,
        pub end: Option<FnEnd>,
        pub end_all: Option<FnEndAll>,
        pub did_foreground: Option<FnDidForeground>,
        pub read_diagnostics: Option<FnReadDiagnostics>,
    }

    static FNS: OnceLock<LiveActivityFns> = OnceLock::new();

    fn dlsym(name: &'static [u8]) -> *mut c_void {
        // Safety: `dlsym` is thread-safe. `CString::new` will append the
        // trailing NUL — the byte slice we pass must NOT contain one
        // already, or it returns `Err(NulError)` and dlsym never runs.
        unsafe extern "C" {
            fn dlsym(handle: *mut c_void, symbol: *const c_char) -> *mut c_void;
        }
        // On Apple platforms `RTLD_DEFAULT` is `((void *) -2)`, not NULL.
        // The historical "0" handle is glibc's convention; passing NULL to
        // `dlsym` on iOS is undefined behavior and returns NULL, which makes
        // every `Option<Fn*>` here stay `None` and silently breaks the
        // entire Live Activity / Widget pipeline. The C functions in
        // FFLiveActivityBridge.mm are linked into the main executable, so
        // searching the global scope via RTLD_DEFAULT finds them.
        let handle: *mut c_void = -2isize as *mut c_void;
        let cstr = match CString::new(name) {
            Ok(c) => c,
            Err(_) => return std::ptr::null_mut(),
        };
        unsafe { dlsym(handle, cstr.as_ptr()) }
    }

    fn load() -> LiveActivityFns {
        unsafe fn sym<T>(name: &'static [u8]) -> Option<T> {
            let ptr = dlsym(name);
            if ptr.is_null() {
                None
            } else {
                Some(std::mem::transmute_copy(&ptr))
            }
        }
        LiveActivityFns {
            is_available: unsafe { sym::<FnIsAvailable>(b"ff_live_activity_is_available") },
            is_enabled: unsafe { sym::<FnIsEnabled>(b"ff_live_activity_is_enabled") },
            set_enabled: unsafe { sym::<FnSetEnabled>(b"ff_live_activity_set_enabled") },
            start: unsafe { sym::<FnStart>(b"ff_live_activity_start") },
            update: unsafe { sym::<FnUpdate>(b"ff_live_activity_update") },
            end: unsafe { sym::<FnEnd>(b"ff_live_activity_end") },
            end_all: unsafe { sym::<FnEndAll>(b"ff_live_activity_end_all") },
            did_foreground: unsafe { sym::<FnDidForeground>(b"ff_live_activity_did_foreground") },
            read_diagnostics: unsafe {
                sym::<FnReadDiagnostics>(b"ff_live_activity_read_diagnostics")
            },
        }
    }

    pub fn fns() -> &'static LiveActivityFns {
        FNS.get_or_init(load)
    }
}

#[cfg(target_os = "ios")]
fn cstr(s: &str) -> CString {
    CString::new(s).unwrap_or_else(|_| CString::new("").unwrap())
}

#[cfg(target_os = "ios")]
#[tauri::command]
pub fn live_activity_is_available() -> bool {
    let f = match loader::fns().is_available {
        Some(f) => f,
        None => return false,
    };
    unsafe { f() }
}

#[cfg(not(target_os = "ios"))]
#[tauri::command]
pub fn live_activity_is_available() -> bool {
    false
}

#[cfg(target_os = "ios")]
#[tauri::command]
pub fn live_activity_is_enabled() -> bool {
    let f = match loader::fns().is_enabled {
        Some(f) => f,
        None => return false,
    };
    unsafe { f() }
}

#[cfg(not(target_os = "ios"))]
#[tauri::command]
pub fn live_activity_is_enabled() -> bool {
    false
}

#[cfg(target_os = "ios")]
#[tauri::command]
pub fn live_activity_set_enabled(enabled: bool) {
    if let Some(f) = loader::fns().set_enabled {
        unsafe { f(enabled) }
    }
}

#[cfg(not(target_os = "ios"))]
#[tauri::command]
pub fn live_activity_set_enabled(_enabled: bool) {}

#[cfg(target_os = "ios")]
#[tauri::command]
pub fn live_activity_start(
    session_id: String,
    phase: String,
    total_seconds: i32,
    task_name: Option<String>,
    cycle_index: i32,
    cycle_total: i32,
) -> bool {
    let f = match loader::fns().start {
        Some(f) => f,
        None => return false,
    };
    let sid = cstr(&session_id);
    let p = cstr(&phase);
    let name = task_name.as_deref().map(cstr);
    let name_ptr = name
        .as_ref()
        .map(|s| s.as_ptr())
        .unwrap_or(std::ptr::null());
    unsafe {
        f(
            sid.as_ptr(),
            p.as_ptr(),
            total_seconds,
            name_ptr,
            cycle_index,
            cycle_total,
        )
    }
}

#[cfg(not(target_os = "ios"))]
#[tauri::command]
pub fn live_activity_start(
    _session_id: String,
    _phase: String,
    _total_seconds: i32,
    _task_name: Option<String>,
    _cycle_index: i32,
    _cycle_total: i32,
) -> bool {
    false
}

#[cfg(target_os = "ios")]
#[tauri::command]
pub fn live_activity_update(
    seconds_remaining: i32,
    is_paused: bool,
    phase: String,
    task_name: Option<String>,
    cycle_index: i32,
    cycle_total: i32,
) -> bool {
    let f = match loader::fns().update {
        Some(f) => f,
        None => return false,
    };
    let p = cstr(&phase);
    let name = task_name.as_deref().map(cstr);
    let name_ptr = name
        .as_ref()
        .map(|s| s.as_ptr())
        .unwrap_or(std::ptr::null());
    unsafe {
        f(
            seconds_remaining,
            is_paused,
            p.as_ptr(),
            name_ptr,
            cycle_index,
            cycle_total,
        )
    }
}

#[cfg(not(target_os = "ios"))]
#[tauri::command]
pub fn live_activity_update(
    _seconds_remaining: i32,
    _is_paused: bool,
    _phase: String,
    _task_name: Option<String>,
    _cycle_index: i32,
    _cycle_total: i32,
) -> bool {
    false
}

#[cfg(target_os = "ios")]
#[tauri::command]
pub fn live_activity_end() -> bool {
    let f = match loader::fns().end {
        Some(f) => f,
        None => return false,
    };
    unsafe { f() }
}

#[cfg(not(target_os = "ios"))]
#[tauri::command]
pub fn live_activity_end() -> bool {
    false
}

#[cfg(target_os = "ios")]
#[tauri::command]
pub fn live_activity_end_all() {
    if let Some(f) = loader::fns().end_all {
        unsafe { f() }
    }
}

#[cfg(not(target_os = "ios"))]
#[tauri::command]
pub fn live_activity_end_all() {}

#[cfg(target_os = "ios")]
#[tauri::command]
pub fn live_activity_did_foreground() {
    if let Some(f) = loader::fns().did_foreground {
        unsafe { f() }
    }
}

#[cfg(not(target_os = "ios"))]
#[tauri::command]
pub fn live_activity_did_foreground() {}

/// Return a diagnostic string the Swift side has written to the App Group
/// shared UserDefaults. The JS layer can display this verbatim so we can
/// see exactly what the iOS side saw at runtime.
#[cfg(target_os = "ios")]
#[tauri::command]
pub fn live_activity_diagnostics() -> String {
    let f = match loader::fns().read_diagnostics {
        Some(f) => f,
        None => return "diagnostics symbol not found (dlsym failed)".to_string(),
    };
    let ptr = unsafe { f() };
    if ptr.is_null() {
        return "diagnostics returned null".to_string();
    }
    let s = unsafe { std::ffi::CStr::from_ptr(ptr) };
    s.to_string_lossy().into_owned()
}

#[cfg(not(target_os = "ios"))]
#[tauri::command]
pub fn live_activity_diagnostics() -> String {
    "iOS-only".to_string()
}
