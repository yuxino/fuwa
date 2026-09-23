# Disposable virtual-display fixture

Local manual QA only; never linked into Fuwa or launched by ordinary tests/CI.

`FuwaQAVirtualDisplay.h` is from [DeskPad at c3349f0](https://github.com/Stengo/DeskPad/blob/c3349f0e237e000cb4826fb3ea1cdd1c44949461/DeskPad/CGVirtualDisplayPrivate.h), under the included MIT license. It declares private macOS APIs, whose availability can change. `FuwaDisplayQA.m` creates one virtual 1080p display and a counter window. Quit the fixture to remove the display; it also exits automatically after ten minutes. Creating/removing a display may rearrange windows.

Build from the repository root:

```sh
mkdir -p /private/tmp/FuwaDisplayQA.app/Contents/MacOS
cp scripts/qa/virtual-display/Info.plist /private/tmp/FuwaDisplayQA.app/Contents/Info.plist
clang -fobjc-arc -framework Cocoa -framework CoreGraphics \
  scripts/qa/virtual-display/FuwaDisplayQA.m \
  -o /private/tmp/FuwaDisplayQA.app/Contents/MacOS/FuwaDisplayQA
open /private/tmp/FuwaDisplayQA.app
```

The window can initially be constrained to the main screen by AppKit. Use its **Move to virtual display** button and verify the source's actual coordinates; opening the app is not proof of secondary-screen placement.

With the fixture running and existing screen recording permission for the test host:

```sh
FUWA_VIRTUAL_CAPTURE_QA=1 swift test --filter VirtualDisplayCaptureTests
```

The test captures only the fixture using production `PinSession`/`CaptureView` code. It does not request permissions. It samples every two seconds for 40 steps, freezes at step 25, and resumes at step 30. During the live intervals, use the fixture buttons to move between displays. Inspect `/private/tmp/fuwa-capture-qa/frames.tsv` for actual coordinates and pixel sizes. Saved PNGs come from the real captured pixel buffer, not desktop screenshot compositing. They do not prove that the final compositor displayed each frame.

Ordinary `swift test` skips this interactive probe. Do not run concurrent probes: their diagnostic output path is shared. Preserve desired output before another run, then unpin any installed-app test pins and quit the fixture.
