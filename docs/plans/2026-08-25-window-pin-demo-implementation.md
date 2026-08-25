# WindowPinDemo Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a minimal macOS menu-bar app that pins a live mirror of the frontmost window with `⌥⌘P`.

**Architecture:** A Swift Package executable runs an AppKit status-bar app. Carbon handles the global shortcut, Core Graphics selects the frontmost window, and ScreenCaptureKit streams that window into a floating `NSPanel`.

**Tech Stack:** Swift 6.2, AppKit, ScreenCaptureKit, AVFoundation, CoreGraphics, Carbon, a dependency-free logic test runner.

---

### Task 1: Project skeleton and pure window-selection logic

**Files:**
- Create: `Package.swift`
- Create: `Sources/WindowPinCore/WindowSelection.swift`
- Create: `Tests/WindowPinDemoLogicTests/main.swift`

1. Write tests for normal-layer filtering, target PID matching, exclusion IDs, minimum size, and Quartz-to-AppKit frame conversion.
2. Run `swift run WindowPinDemoLogicTests` and verify the missing symbols fail compilation.
3. Implement the smallest pure selection and coordinate helpers.
4. Run `swift run WindowPinDemoLogicTests` and verify all tests pass.

### Task 2: Global hotkey and application lifecycle

**Files:**
- Create: `Sources/WindowPinDemo/main.swift`
- Create: `Sources/WindowPinDemo/AppDelegate.swift`
- Create: `Sources/WindowPinDemo/GlobalHotKey.swift`

1. Start an accessory AppKit application with a monochrome menu-bar icon.
2. Register `⌥⌘P` through Carbon `RegisterEventHotKey`.
3. Route each press to a single toggle method and expose Pin, Cancel, permission settings, and Quit menu actions.
4. Build with `swift build` and verify there are no warnings or errors.

### Task 3: ScreenCaptureKit floating overlay

**Files:**
- Create: `Sources/WindowPinDemo/PinnedWindowController.swift`
- Create: `Sources/WindowPinDemo/CaptureView.swift`

1. Resolve the selected CGWindow ID to an `SCWindow`.
2. Create a borderless, mouse-transparent floating `NSPanel` at the target frame.
3. Stream frames into `AVSampleBufferDisplayLayer` and keep its size synchronized.
4. Track target frame/closure and stop the stream cleanly when unpinned.
5. Run the logic test runner and a debug build.

### Task 4: Bundle, documentation, and manual verification

**Files:**
- Create: `Resources/Info.plist`
- Create: `scripts/package-app.sh`
- Create: `README.md`
- Create: `.gitignore`

1. Package the release executable into `dist/WindowPinDemo.app` with the screen-capture purpose string.
2. Run `swift run WindowPinDemoLogicTests`, `swift build -c release`, and the packaging script.
3. Launch the app, grant Screen Recording if requested, and verify `⌥⌘P` pins and unpins a normal app window.
4. Initialize a `main` Git repository and commit the verified demo.
