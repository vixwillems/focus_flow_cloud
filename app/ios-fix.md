# iOS Build Guide for FocusFlow

This document explains how to build the FocusFlow iOS app on a Mac with Xcode 27 beta, working around Tauri 2.11.2 / swift-rs 1.0.7 incompatibilities with the macOS 27 beta SDK.

## Context

- **Tauri:** 2.11.2 (uses `swift-rs` 1.0.7 git dependency to compile Swift code for iOS)
- **Xcode versions installed:** Xcode 27 beta (`/Applications/Xcode-beta.app`) and Xcode 26.6 (`/Applications/Xcode.app`)
- **Devices:** iPhone 16 Pro Max running iOS 27 dev beta, iPad Pro M4 running iOS 27 dev beta
- **Apple ID type:** Free (no paid developer subscription) — signing certificates expire every 7 days
- **Bundle identifier:** `com.francescopio.focusflow`
- **Team ID used:** `88QN5KYG2G` ("Vix Willems (Personal Team)" in Xcode → Settings → Accounts)

## The Problem

Tauri's iOS build process runs `swift build` via `swift-rs`'s build script, which compiles a Swift package (`mobile/ios-api`) for both iOS target and macOS host. Under Xcode 27 beta's macOS 27 SDK, several headers were removed/broken:

1. `OpenGLES/EAGL.h` — removed entirely from macOS 27 SDK (but referenced by `CoreImage/CIContext.h`)
2. `CoreServices/CSIdentityBase.h`, `CSIdentityAuthority.h`, `CSIdentityQuery.h` — exist only in `OSServices.framework`, but `CSIdentity.h` references them as `<CoreServices/*>`
3. `UIKit/*` headers — WebKit on macOS 27 imports UIKit (it doesn't exist on macOS normally)

Additionally, Xcode 26 cannot deploy to iOS 27 devices (SDK version mismatch — Xcode 26's SDK is iOS 26.5, but the device runs iOS 27). So we must build with **Xcode 27** to deploy to iOS 27 devices, but the Tauri build chain breaks on macOS 27 SDK.

**Surprise resolution:** The actual build succeeded using **Xcode 26** (despite the SDK mismatch warnings). Xcode 26 was apparently able to deploy to the iOS 27 device. If this stops working, fall back to Xcode 27 + the SDK patches documented below.

## Working Build Command

```sh
# From repo root, with xcode-select pointing to Xcode 26:
xcode-select -s /Applications/Xcode.app/Contents/Developer

# Build for connected iPhone (or any iOS 27 device)
cd app
bun run tauri ios build --debug --target aarch64
```

Output: `app/src-tauri/gen/apple/build/arm64/FocusFlow.ipa`

Install on device:
```sh
xcrun devicectl device install app app/src-tauri/gen/apple/build/arm64/FocusFlow.ipa
```

## Setup Steps (one-time, on a fresh Mac)

### 1. Verify Apple ID is added to Xcode

Open Xcode → Settings → Accounts. Confirm the personal Apple ID shows up with a "Personal Team". Note the team ID (e.g. `88QN5KYG2G`).

If not present, click "+" and add the Apple ID. Xcode will create a Personal Team automatically.

### 2. Accept Xcode 26 license (if not already)

```sh
sudo xcodebuild -license
```

Read and accept the license. Repeat for Xcode 27 if you also use it:

```sh
sudo /Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild -license
```

### 3. Update development team in the Xcode project

`app/src-tauri/gen/apple/focus-flow.xcodeproj/project.pbxproj` has hardcoded `DEVELOPMENT_TEAM` and `DevelopmentTeam` values. Replace `88QN5KYG2G` (the user's team) with yours if different:

```sh
sed -i '' 's/88QN5KYG2G/YOUR_TEAM_ID/g' \
  app/src-tauri/gen/apple/focus-flow.xcodeproj/project.pbxproj
```

### 4. Apply macOS 27 SDK patches (only needed if you go back to Xcode 27)

These patches add missing headers in the macOS 27 SDK that Tauri/swift-rs needs. **All require sudo.** Run each block as a single sudo shell:

```sh
sudo bash -c '
SDK=/Applications/Xcode-beta.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk

# 4a. Add OpenGLES framework stubs (header was removed from macOS 27 SDK)
mkdir -p "$SDK/System/Library/Frameworks/OpenGLES.framework/Headers"
cat > "$SDK/System/Library/Frameworks/OpenGLES.framework/Headers/EAGL.h" <<EOF
#ifndef EAGL_H
#define EAGL_H
#import <Foundation/NSObject.h>
#endif
EOF
cat > "$SDK/System/Library/Frameworks/OpenGLES.framework/Headers/module.modulemap" <<EOF
framework module OpenGLES {
  umbrella header "EAGL.h"
  export *
  module * { export * }
}
EOF

# 4b. Symlink CSIdentity* headers from OSServices into CoreServices Headers
TARGET="$SDK/System/Library/Frameworks/CoreServices.framework/Headers"
SOURCE="$SDK/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/OSServices.framework/Versions/A/Headers"
mkdir -p "$TARGET"
rm -f "$TARGET/CSIdentityBase.h" "$TARGET/CSIdentityAuthority.h" \
      "$TARGET/CSIdentityQuery.h" "$TARGET/CSIdentity.h" "$TARGET/Headers"
for f in CSIdentityBase.h CSIdentityAuthority.h CSIdentityQuery.h CSIdentity.h; do
  ln -sf "$SOURCE/$f" "$TARGET/$f"
done

# 4c. Add UIKit framework stubs (WebKit on macOS 27 imports UIKit)
UIKIT="$SDK/System/Library/Frameworks/UIKit.framework/Headers"
mkdir -p "$UIKIT"
for h in NSAttributedString.h UIKeyCommand.h UIViewController.h; do
  printf "#import <Foundation/NSObject.h>\n" > "$UIKIT/$h"
done
# Umbrella header
cat > "$UIKIT/UIKit.h" <<EOF
#ifndef UIKIT_UMBRELLA
#define UIKIT_UMBRELLA
#import <UIKit/NSAttributedString.h>
#endif
EOF
'
```

**Note:** If you build successfully with Xcode 26 first (the actual working path), you can skip all the patches above.

## Build Flow (recap)

```
+----------------------------+
| bun run tauri ios build    |
+-------------+--------------+
              |
              v
+----------------------------+
| vite build (SvelteKit)     |  -> app/build/ (static SPA)
+-------------+--------------+
              |
              v
+----------------------------+
| xcodebuild (Xcode 26 SDK)  |  -> FocusFlow.app / .ipa
|   - tauri ios xcode-script |
|     - cargo build iOS      |
|       - rust code compiles |
|     - swift-rs build.rs    |
|       - swift build        |
|         (macOS 27 SDK OK   |
|          because we use    |
|          Xcode 26 toolchain)|
+-------------+--------------+
              |
              v
+----------------------------+
| devicectl install app      |  -> iPhone (iOS 27)
+----------------------------+
```

## Weekly Cert Renewal (free Apple ID)

Free Apple IDs have signing certificates that expire after **7 days**. When the app stops launching on the iPhone with "untrusted developer":

1. Re-run the build: `bun run tauri ios build --debug --target aarch64`
2. Reinstall: `xcrun devicectl device install app app/src-tauri/gen/apple/build/arm64/FocusFlow.ipa`
3. On the iPhone: Settings → General → VPN & Device Management → tap the Apple ID → Trust (only needed if the cert has changed)

You can also re-sign without rebuilding via Xcode: Window → Devices and Simulators → select device → long-press the app → "Reinstall" or just drag a fresh build.

## Build Config Tweaks (already in place)

- `app/src-tauri/tauri.conf.json` → `version: "1.1.0"`, `identifier: "com.francescopio.focusflow"`
- `app/src-tauri/gen/apple/focus-flow.xcodeproj` → `DEVELOPMENT_TEAM = 88QN5KYG2G` (Vix Willems Personal Team)
- `app/package.json` → `version: "1.3.0"` (frontend, separate from Tauri version)
- `app/src-tauri/ios-api/Package.swift` (in cargo registry, regenerated by `tauri ios init`) — targets iOS only (macOS removed)

## SwiftPM/Tauri Build Chain Notes

The Tauri build chain that breaks under Xcode 27 is:

1. `xcodebuild` calls `tauri ios xcode-script`
2. That runs `cargo build --target aarch64-apple-ios --lib`
3. The `tauri` crate's `build.rs` calls `tauri_utils::build::link_apple_library("Tauri", ...)`
4. Which calls `swift_rs::build::SwiftLinker::link()`
5. Which runs `swift build --sdk iphoneos --arch arm64 -Xswiftc -target arm64-apple-ios14.0 ...`
6. SwiftPM builds the Tauri Swift package for both macOS (host) and iOS (target)
7. Under Xcode 27, the macOS 27 SDK has the broken headers → all the patches above

The reason **Xcode 26 works** despite the iOS 27 device mismatch is that Xcode 26's toolchain (`xcrun --find swift` resolves to the Xcode 26 Swift compiler) is used, but the actual iOS SDK is determined per-target. The iOS 26.5 SDK can still produce binaries that run on iOS 27 devices (iOS is backwards-compatible at the ABI level).

## If a future Xcode 27 update fixes the SDK

To switch back to Xcode 27:

```sh
sudo xcode-select -s /Applications/Xcode-beta.app/Contents/Developer
```

Then re-run the build. The SDK patches in step 4 should no longer be needed.

## If a future Xcode update breaks Xcode 26

If Xcode 26 stops working (e.g. a new macOS drops Xcode 26 support), you'll need to:

1. Use Xcode 27 (or later beta)
2. Apply all the SDK patches in step 4
3. Possibly patch the swift-rs build script (`~/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/swift-rs-1.0.7/src-rs/build.rs`) to add `--triple arm64-apple-ios14.0` and `-Xlinker -target arm64-apple-ios14.0` flags

## References

- Tauri iOS build docs: https://v2.tauri.app/distribute/ios/
- Apple free account limitations: https://developer.apple.com/support/compare-memberships/
- SwiftPM cross-compilation: https://forums.swift.org/t/swiftpm-cross-compilation-issues
- Project bundle ID: `com.francescopio.focusflow`
- Personal team: `88QN5KYG2G` (Vix Willems)

## Live Activities, Dynamic Island, Widgets

The iOS app ships a Widget Extension (`FocusFlowWidgets.appex`) that is embedded in the main app. The extension implements:

- **Live Activity** — A timer chip on the Lock Screen and in the Dynamic Island. Driven by Apple's `ActivityKit` framework (iOS 16.1+).
- **StandBy / Home Screen widget** — A calm, monochromatic widget that shows the current timer on the Lock Screen (accessory families) and Home Screen (system small / medium / large). Looks at home in iOS 17+ StandBy mode.

### Architecture

```
+----------------------+         +-------------------------+
|     Svelte Timer     |         |  Shared/                |
|  (liveActivity.ts)   |  invoke |   - SharedTimerState    |
|                      +-------> |   - FocusPhase          |
+----------------------+         +-------------------------+
              |                    ^
              v                    | (also linked into the
+----------------------+         |  widget extension target
| Tauri commands       |         |  so the ActivityAttributes
| (live_activity.rs)   |  dlsym  |  shape is identical)
|                      +-----+   +-------------------------+
+----------------------+     |
              ^              v
              |   +----------------------+
              |   | FFLiveActivityBridge |
              |   | (.mm, extern "C")    |
              |   +----------+-----------+
              |              |
              |              v
              |   +----------------------+
              |   | LiveActivityController  |   App Group: group.com.francescopio.focusflow
              |   | (Swift, ActivityKit)    | <-------------------------------------------+
              |   +----------+-------------+                                             |
              |              |                                                           |
              |              v                                                           |
              |   +----------------------+   +--------------------------------+          |
              |   |   iOS app binary     |   |  FocusFlowWidgets.appex       |          |
              |   |  (main app target)   |   |  (widget extension target)     |          |
              |   |                      |   |                                |          |
              |   |  NSSupportsLive-     |   |  - FocusFlowLiveActivity       |          |
              |   |   Activities = true  |   |  - FocusFlowStandByWidget      |          |
              |   |  App Group ✓         |   |  App Group ✓                   |          |
              |   +----------------------+   +--------------------------------+          |
              |                                                                       |
              +-----------------------------------------------------------------------+
                                          shared state in App Group
```

### Why `dlsym` (not `extern "C"`)

The Rust crate is built *before* the iOS app target. At that point the Swift/Obj-C++ symbols don't exist yet, so a plain `extern "C"` declaration fails at link time with "Undefined symbols". We solve this with `dlsym(RTLD_DEFAULT, "ff_live_activity_*")` at runtime — by the time the Tauri command fires, the iOS app is fully loaded and the symbols resolve to the Swift-side `FFLiveActivityBridge.mm` definitions.

### Where the code lives

- `app/src-tauri/gen/apple/Sources/focus-flow/`
  - `FFLiveActivityBridge.h`, `FFLiveActivityBridge.mm` — C ABI surface; uses `objc_msgSend` to call into the Swift `LiveActivityController`.
  - `LiveActivityController.swift` — `@objc(FFLiveActivity)` class; wraps `Activity<FocusFlowAttributes>` and writes the current state into the App Group `UserDefaults` for the widget to read.
- `app/src-tauri/FocusFlowWidgetExtension/`
  - `FocusFlowWidgetBundle.swift` — `@main` widget bundle.
  - `FocusFlowLiveActivity.swift` — `ActivityConfiguration<FocusFlowAttributes>` (Lock Screen + Dynamic Island).
  - `FocusFlowStandByWidget.swift` — `StaticConfiguration` widget supporting `.accessoryRectangular` / `.accessoryCircular` / `.accessoryInline` (for StandBy) plus `.systemSmall` / `.systemMedium` / `.systemLarge` (for Home Screen).
  - `Info.plist` (with `NSExtension.NSExtensionPointIdentifier = com.apple.widgetkit-extension`).
  - `FocusFlowWidgetExtension.entitlements` (App Group).
- `app/src-tauri/Shared/` (linked into BOTH the main app and the widget extension)
  - `SharedTimerState.swift` — the cross-target state model + App Group read/write helpers.
  - `FocusFlowAttributes.swift` — `ActivityAttributes` definition. Must be byte-compatible between the two targets.
- `app/src-tauri/src/live_activity.rs` — Rust Tauri commands; uses `dlsym` to call into Swift.
- `app/src/lib/liveActivity.ts` — Svelte-side wrapper (auto-detects iOS, throttles updates to once per minute, persists the user's enable/disable choice in `localStorage`).
- `app/src/routes/(app)/timer/+page.svelte` — calls the Live Activity on session start/update/stop.
- `app/src/routes/(app)/settings/+page.svelte` — adds an iOS-only toggle "Show focus timer in Live Activity" (client-side only; no backend persistence needed for a single-user-per-device app).

### How to add a new widget family

1. Add the family to `.supportedFamilies([...])` in `FocusFlowStandByWidget.swift`.
2. Add a matching `case .newFamily:` to the `switch family` in `FocusFlowStandByEntryView`.
3. Implement a new `struct NewFamilyView: View { ... }`.
4. `xcodegen generate && bun run tauri ios build --debug --target aarch64`.

### Live Activity update budget

The Svelte side throttles Live Activity updates to one per minute (well within Apple's budget). The bridge and the controller also write to the App Group on every update, so the StandBy widget can read the latest state without needing a separate IPC.

### If the widget extension doesn't show up in the iPhone's widget gallery

1. Re-install the app — widgets are discovered from the bundle.
2. Settings → FocusFlow → confirm the Live Activity toggle is on (iOS 16+ also has a per-app Live Activity master switch in the Settings app).
3. The StandBy / Home Screen widget is registered as a `StaticConfiguration`, not `AppIntentConfiguration`, so it doesn't require user setup.
4. If using a free Apple ID, signing certs expire every 7 days — re-build and re-install.

### `project.yml` is the source of truth for the iOS Xcode project

The `focus-flow.xcodeproj` is auto-generated by `xcodegen` from `gen/apple/project.yml`. If you add new sources, change deployment targets, or add new targets (e.g. another extension), edit `project.yml` and re-emit with:

```sh
./app/src-tauri/scripts/regen_xcode.sh
```
