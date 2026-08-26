# Fuwa Implementation Plan

**Goal:** Turn the existing WindowPinDemo provenance base into Fuwa, a polished public macOS menu-bar app that pins capturable windows reliably, supports Finder Quick Look, multiple live/frozen pins, and permission-on-demand interaction.

**Architecture:** A Swift 6 modular monolith keeps deterministic selection/state logic in `FuwaCore` and AppKit/SwiftUI/ScreenCaptureKit integrations in `Fuwa`. `TargetResolver` combines the foreground process, CGWindow z-order, narrow Quick Look helper exceptions, and `SCShareableContent`; `PinCoordinator` owns independent `PinSession` state machines and publishes immutable view models to a neutral SwiftUI popover.

**Tech Stack:** Swift 6.2, AppKit, SwiftUI, ScreenCaptureKit, AVFoundation, CoreGraphics, Accessibility, ServiceManagement, a dependency-free executable logic-test harness, shell packaging, GitHub Actions.

---

## Environment note

The development Mac has Command Line Tools rather than full Xcode, and its compatible macOS 15.4 SDK exposes neither XCTest nor Swift Testing. The plan therefore uses the `FuwaLogicTests` executable target and fails the process on any assertion. CI runs the same target. This keeps the test suite dependency-free and executable both locally and on GitHub-hosted macOS runners.

### Task 1: Rebrand the provenance base

**Files:**
- Modify: `Package.swift`
- Move: `Sources/WindowPinCore` → `Sources/FuwaCore`
- Move: `Sources/WindowPinDemo` → `Sources/Fuwa`
- Move: `Tests/WindowPinDemoLogicTests` → `Tests/FuwaLogicTests`
- Modify: `Resources/Info.plist`
- Modify: `.gitignore`

**Steps:**

1. Rename package, products, targets, imports, executable and bundle identifiers to `Fuwa` / `FuwaCore` / `app.yuxino.fuwa`.
2. Keep a dependency-free executable `FuwaLogicTests` target and split its suites into callable functions.
3. Add `swiftLanguageModes: [.v6]` and keep macOS 14 as the minimum.
4. Run `swift run FuwaLogicTests` and verify the renamed baseline passes.
5. Commit with `refactor: establish Fuwa project foundation`.

### Task 2: Specify target selection with failing tests

**Files:**
- Create: `Sources/FuwaCore/WindowDescriptor.swift`
- Create: `Sources/FuwaCore/SelectionPolicy.swift`
- Create: `Tests/FuwaLogicTests/SelectionPolicyTests.swift`
- Create: `Tests/FuwaLogicTests/TestHarness.swift`
- Remove: `Sources/FuwaCore/WindowSelection.swift`

**Required tests:**

```swift
func testFinderQuickLookLayerThreeWinsOverFinderMainWindow() {
    let windows = [
        fixture(id: 3662, pid: 619, layer: 3, size: .init(width: 575, height: 328)),
        fixture(id: 3962, pid: 619, layer: 0, size: .init(width: 920, height: 436))
    ]
    XCTAssertEqual(SelectionPolicy.intentWindow(in: windows, context: context)?.id, 3662)
}

func testIndependentQLManageWindowIsNotRejectedByFrontmostPID() {
    let windows = [
        fixture(id: 3885, pid: 16762, owner: "qlmanage", layer: 0),
        fixture(id: 100, pid: 619, owner: "Finder", layer: 0)
    ]
    XCTAssertEqual(SelectionPolicy.intentWindow(in: windows, context: context)?.id, 3885)
}

func testUnshareableIntentDoesNotFallThroughToWindowBehindIt() {
    let intent = fixture(id: 1, pid: 10)
    let behind = fixture(id: 2, pid: 20)
    XCTAssertEqual(SelectionPolicy.intentWindow(in: [intent, behind], context: context)?.id, 1)
    XCTAssertNil(SelectionPolicy.confirm(intent, shareableWindowIDs: [2]))
}
```

**Steps:**

1. Add Quick Look, qlmanage, system UI, self-window, transparent, tiny, off-screen and unshareable-race fixtures.
2. Run `swift run FuwaLogicTests` and confirm the new assertions fail before implementation.
3. Implement the two-stage policy: choose visual intent first, then confirm the exact ID is shareable.
4. Keep PID and layer as metadata only; exclude system UI using bundle identifiers plus defensive geometry rules.
5. Run the focused tests, then the full suite.
6. Commit with `feat: resolve the frontmost capturable window`.

### Task 3: Add core state and settings models

**Files:**
- Create: `Sources/FuwaCore/PinState.swift`
- Create: `Sources/FuwaCore/KeyboardShortcut.swift`
- Create: `Tests/FuwaLogicTests/PinStateTests.swift`
- Create: `Tests/FuwaLogicTests/KeyboardShortcutTests.swift`

**Steps:**

1. Write state-transition tests for resolving, starting, live, frozen, failed, stopping and stopped.
2. Write shortcut validation/serialization tests, including conflict-safe rollback.
3. Run the focused tests and verify failure.
4. Implement immutable value types with no AppKit dependency where possible.
5. Run all tests and commit with `feat: add pin and shortcut domain models`.

### Task 4: Implement the ScreenCaptureKit target resolver

**Files:**
- Create: `Sources/Fuwa/TargetResolver.swift`
- Create: `Sources/Fuwa/WindowInventory.swift`
- Create: `Sources/Fuwa/DisplayCoordinateSpace.swift`
- Create: `Tests/FuwaLogicTests/DisplayCoordinateSpaceTests.swift`

**Steps:**

1. Add multi-display coordinate fixtures, including displays left of and above the primary display.
2. Confirm coordinate tests fail before implementation.
3. Snapshot ordered CG windows synchronously at shortcut time.
4. Fetch `SCShareableContent`, confirm the exact intent window, and return a `ResolvedTarget` containing its `SCWindow` and descriptor.
5. If the intent disappears or is unavailable, return a typed error without selecting the next window.
6. Centralize Quartz/AppKit conversion in `DisplayCoordinateSpace`.
7. Run tests and a strict build; commit with `feat: resolve ScreenCaptureKit targets`.

### Task 5: Build an explicit multi-pin capture state machine

**Files:**
- Replace: `Sources/Fuwa/PinnedWindowController.swift`
- Create: `Sources/Fuwa/PinCoordinator.swift`
- Create: `Sources/Fuwa/PinSession.swift`
- Modify: `Sources/Fuwa/CaptureView.swift`
- Create: `Sources/Fuwa/WindowTracker.swift`

**Steps:**

1. Preserve complete-frame validation, stream identity checks, resize serialization and queue depth 3 from the demo.
2. Give every start/stop cycle a generation; reject callbacks whose stream or generation is stale.
3. Delay `orderFrontRegardless()` until the first complete frame.
4. Support independent sessions in a coordinator keyed by stable UUID and source window ID.
5. Use one adaptive CG inventory timer for all live sessions; stop it when no sessions are live.
6. Update geometry and pixel scale after move, resize and display changes.
7. Make stop idempotent and hide UI before asynchronous stream teardown.
8. Run a 100-cycle pin/unpin stress harness and strict build.
9. Commit with `feat: support reliable multi-window pins`.

### Task 6: Preserve the last frame and add Freeze/Resume

**Files:**
- Modify: `Sources/Fuwa/CaptureView.swift`
- Modify: `Sources/Fuwa/PinSession.swift`
- Modify: `Sources/Fuwa/PinCoordinator.swift`
- Create: `Tests/FuwaLogicTests/FreezePolicyTests.swift`

**Steps:**

1. Add pure policy tests: source gone after first frame freezes; source gone before first frame fails; manual freeze stops capture; resume requires source existence.
2. Retain only the latest complete pixel buffer while live.
3. Convert it to a size-capped CGImage when freezing and release the stream.
4. Keep the panel visible with a subtle frozen indicator; do not retain source pixels after unpin/lock/quit.
5. Resume with a fresh SCWindow lookup and generation.
6. Test Finder image/PDF Quick Look close-to-Frozen behavior manually.
7. Commit with `feat: keep transient windows as frozen pins`.

### Task 7: Add permission-on-demand source interaction

**Files:**
- Create: `Sources/Fuwa/PermissionCenter.swift`
- Create: `Sources/Fuwa/InteractionCoordinator.swift`
- Create: `Sources/Fuwa/AccessibilityWindowResolver.swift`
- Modify: `Sources/Fuwa/PinCoordinator.swift`

**Steps:**

1. Implement read-only permission status checks with no launch-time prompt.
2. On first Interact, show an in-app rationale, then call `AXIsProcessTrustedWithOptions` only after user intent.
3. Match AXWindow by PID and geometry tolerance; do not depend on localized title or Quick Look subrole.
4. Activate the source app and perform `kAXRaiseAction`; keep the mirror mouse-through.
5. Allow only one engaged source and return typed `viewOnly` reasons on failure.
6. Verify no Accessibility prompt appears during launch, Pin, Freeze or Unpin.
7. Commit with `feat: reveal pinned source windows on demand`.

### Task 8: Create the menu-bar product experience

**Files:**
- Replace: `Sources/Fuwa/AppDelegate.swift`
- Create: `Sources/Fuwa/AppModel.swift`
- Create: `Sources/Fuwa/StatusBarController.swift`
- Create: `Sources/Fuwa/Popover/FuwaPopoverView.swift`
- Create: `Sources/Fuwa/Popover/PinRowView.swift`
- Create: `Sources/Fuwa/Popover/SettingsView.swift`
- Modify: `Sources/Fuwa/GlobalHotKey.swift`
- Create: `Sources/Fuwa/Localization.swift`
- Create: `Resources/en.lproj/Localizable.strings`
- Create: `Resources/zh-Hans.lproj/Localizable.strings`

**Steps:**

1. Add an `AppModel` that receives immutable pin snapshots and permission/settings status.
2. Replace the menu with an `NSPopover` hosting a keyboard-accessible SwiftUI single-column interface.
3. Implement Pin, Freeze/Resume, Interact/Reveal, Unpin and Clear All actions.
4. Add Launch at Login through `SMAppService.mainApp` with explicit error feedback.
5. Add shortcut recording, validation, persistence and rollback if Carbon registration fails.
6. Localize every user-facing string in English and Simplified Chinese.
7. Add VoiceOver labels, tooltips, visible focus and reduced-motion behavior.
8. Render and inspect both locales at normal and increased text size.
9. Commit with `feat: add the Fuwa menu bar experience`.

### Task 9: Handle privacy-sensitive lifecycle events

**Files:**
- Create: `Sources/Fuwa/PrivacyLifecycle.swift`
- Modify: `Sources/Fuwa/AppDelegate.swift`
- Modify: `Sources/Fuwa/PinCoordinator.swift`
- Modify: `Sources/Fuwa/Resources/Info.plist`

**Steps:**

1. Observe sleep, wake, session resign/activate, screen lock/unlock and display reconfiguration.
2. On lock, session switch or quit: hide panels, stop streams and clear frozen pixels.
3. On sleep: stop live streams safely; do not expose stale pixels on wake.
4. If Screen Recording is revoked, move sessions to a clear failed/stopped state.
5. Ensure logs contain IDs/state/timing only, never titles or pixel data.
6. Commit with `feat: protect captured content across system lifecycle`.

### Task 10: Brand, package and document the app

**Files:**
- Create: `Assets/AppIcon.iconset/*`
- Create: `Resources/AppIcon.icns`
- Replace: `scripts/package-app.sh`
- Create: `scripts/verify-app.sh`
- Create: `scripts/create-release-archive.sh`
- Create: `LICENSE`
- Replace: `README.md`
- Create: `README_zh.md`
- Create: `PRIVACY.md`
- Create: `CONTRIBUTING.md`
- Create: `SECURITY.md`
- Create: `CHANGELOG.md`
- Create: `docs/independent-implementation.md`

**Steps:**

1. Create an original Fuwa mascot within the established Kiri/mimi product family and verify its transparent master and derived icon at 16–1024 px.
2. Package a universal2 app with localized resources and icon.
3. Require a persistent private-key-backed signing identity for every runnable preview or package; support optional Developer ID signing/notarization through explicit environment inputs.
4. Verify plist, architecture, signature, minimum OS, permissions text and absence of quarantine in the build directory.
5. Write concise bilingual usage, permission, limitations, architecture and build documentation.
6. Document independent provenance from commits `dcb0a62`, `d473418`, `c834316` and public Apple APIs.
7. Capture polished Quick Look and popover screenshots.
8. Commit with `docs: prepare Fuwa for public release`.

### Task 11: Add CI and release automation

**Files:**
- Create: `.github/workflows/ci.yml`
- Create: `.github/workflows/release.yml`
- Create: `.github/ISSUE_TEMPLATE/bug_report.yml`
- Create: `.github/pull_request_template.md`

**Steps:**

1. Run tests and warnings-as-errors release builds on GitHub-hosted macOS.
2. Package and verify the app in CI.
3. On `v*` tags, create a universal2 ZIP, SHA-256 checksum and GitHub Release.
4. Use Developer ID/notarization secrets only when all required secrets exist; otherwise label the artifact as an ad-hoc preview.
5. Lint workflow YAML and run local equivalents.
6. Commit with `ci: automate Fuwa verification and releases`.

### Task 12: Complete runtime QA and publish

**Files:**
- Create: `docs/qa/v0.1.0.md`
- Modify: `CHANGELOG.md`

**Steps:**

1. Run `swift run FuwaLogicTests` and strict debug/release builds.
2. Package and verify universal2 Fuwa.app.
3. Test ordinary App windows, Finder JPEG/PNG/PDF/video Quick Look and `qlmanage`.
4. Test multiple pins, Freeze/Resume, source closure, move/resize, multiple displays, Spaces, full screen and Stage Manager.
5. Test rapid toggle, sleep/wake, lock/unlock, permission denial/revocation and both locales.
6. Record exact evidence and known hardware-dependent gaps in `docs/qa/v0.1.0.md`.
7. Create public `yuxino/fuwa`, add `origin`, push `main`, and confirm the remote tree and CI.
8. Tag `v0.1.0`, push the tag, wait for CI/release, download the published artifact and verify checksum/signature/launch.
9. Update release notes only if published evidence differs from local QA.
10. Perform a requirement-by-requirement completion audit against the product design.
