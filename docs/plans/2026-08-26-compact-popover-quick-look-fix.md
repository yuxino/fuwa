# Compact Popover and Quick Look Reliability Implementation Plan

**Goal:** Collapse Fuwa's empty Pins area and make the popover button reliably target transient Finder Quick Look windows.

**Architecture:** Keep the existing multi-Pin list for active sessions, but select a compact popover presentation when the Pins route is ready and empty. Capture one `TargetIntentSnapshot` immediately before the popover becomes key, keep it only for that popover lifetime, and consume it when the primary button runs. Confirm ScreenCaptureKit availability by the globally unique WindowServer ID; retain PID only for source liveness and later interaction checks.

**Tech Stack:** Swift 6, SwiftUI, AppKit, CoreGraphics, ScreenCaptureKit, Swift Package Manager.

---

### Task 1: Preserve the target visible before the popover opens

**Files:**
- Modify: `Sources/Fuwa/AppDelegate.swift`
- Modify: `Sources/Fuwa/StatusBarController.swift`

**Step 1: Add one-shot target storage**

Add `preparedPinIntent` to `AppDelegate`. Expose two callbacks to `StatusBarController`: one snapshots the frontmost target before `NSPopover.show`, and one discards it when the popover closes.

**Step 2: Consume or clear the target at every boundary**

Use the prepared intent in `pinFrontWindow()` when present, clear it before global-hotkey targeting, consume it before starting asynchronous capture, and clear it on popover close and app termination.

**Step 3: Build the application target**

Run:

```sh
env SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk \
  CLANG_MODULE_CACHE_PATH=/private/tmp/fuwa-clang-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/fuwa-swift-cache \
  swift build --disable-sandbox --product Fuwa \
  -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
```

Expected: `Build complete!` with no warnings.

### Task 2: Confirm Quick Look by exact WindowServer ID

**Files:**
- Modify: `Sources/Fuwa/TargetResolver.swift`
- Modify: `Tests/FuwaLogicTests/SelectionPolicyTests.swift`

**Step 1: Strengthen the Quick Look fixtures**

Add a cross-process `QuickLookUIService` fixture and keep the confirmation test explicit that capture availability is determined by the exact window ID, not by the owning PID reported through another API.

**Step 2: Run the logic suite before changing the resolver**

Run `swift run --disable-sandbox FuwaLogicTests` with the same SDK and module-cache environment. Expected: existing tests pass; the new fixture documents the intended cross-process behavior.

**Step 3: Reuse the tested exact-ID confirmation policy**

Build a set of `SCWindow.windowID` values, confirm the selected descriptor with `SelectionPolicy.confirm`, then retrieve the corresponding `SCWindow` by ID only. Do not fall through to another window.

**Step 4: Run the logic suite and strict build**

Expected: `All Fuwa logic tests passed` and a warning-free application build.

### Task 3: Collapse only the empty Pins state

**Files:**
- Modify: `Sources/Fuwa/Popover/PinsView.swift`
- Modify: `Sources/Fuwa/Popover/FuwaPopoverView.swift`
- Modify: `Sources/Fuwa/StatusBarController.swift`

**Step 1: Remove the redundant ready-empty body**

When `contentState == .ready && pins.isEmpty`, render only the primary action. Keep loading, failure, and active-Pin list states unchanged.

**Step 2: Add presentation-aware sizing**

Use a compact height for the empty Pins route, with extra space when a notice exists and larger values for Dynamic Type. Keep the current expanded sizes for Settings, loading/failure, and active Pins. Re-report size when route, pin count, content state, notice, or Dynamic Type changes.

**Step 3: Prevent the first-open height flash**

Initialize `NSPopover` with the compact normal-size dimensions; later model changes and `onAppear` apply the actual preferred size.

**Step 4: Run strict build and inspect both modes**

Expected: no-Pin mode contains header, optional notice, primary button, and footer without a blank body; active-Pin and Settings modes remain expanded and scrollable.

### Task 4: Package, install, and verify the real app

**Files:**
- Verify: `scripts/package-app.sh`
- Verify: `scripts/install-app.sh`
- Verify: `/Applications/Fuwa.app`

**Step 1: Run repository checks**

Run the logic suite, strict release build, `git diff --check`, and inspect the diff.

**Step 2: Package with the existing stable signing identity**

Run `./scripts/package-app.sh`. Expected: the built app has bundle ID `app.yuxino.fuwa`, a non-adhoc designated requirement, and the same requirement as the installed app.

**Step 3: Update the canonical installation**

Quit the running Fuwa copy, run `./scripts/install-app.sh --no-build`, and launch only `/Applications/Fuwa.app`.

**Step 4: Perform native visual QA**

Inspect compact empty mode with and without a permission notice, Settings, and active-Pin mode. Verify that opening the popover over a Finder Quick Look preview preserves the intended target.

**Step 5: Complete Screen Recording verification**

If macOS still reports Screen Recording as denied, stop before changing the privacy setting and ask the user to grant `/Applications/Fuwa.app`. After authorization and relaunch, pin a desktop PNG through both `⌥⌘P` and the popover button; close Quick Look and confirm the pin becomes Frozen.
