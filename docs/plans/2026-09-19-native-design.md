# Fuwa native interaction redesign

Baseline: fd80705 (0.1.8). Original checkout was clean and at the same commit when work began. Scope is Fuwa native only; independent implementation, no copied third-party code or artwork.

## Reference evaluation

Reviewed repository documentation in Ego Lite on 2026-09-19:

| Project | Platform / license | Useful lesson | Boundary |
| --- | --- | --- | --- |
| [Topit](https://github.com/lihaoyun6/Topit) | macOS 13+, AGPL-3.0 | Direct pinning workflow and multiple window management | Strong workflow reference, not a source-code donor for Fuwa's MIT implementation. Latest repository activity shown was two years old. |
| [PinWindow](https://github.com/justwy/PinWindow) | macOS 13+, MIT | Separate pinned list, window titles, menu-bar count | Closest technical comparison; README discloses private AX API and global click monitoring. Do not inherit those choices. |
| [WindowPin](https://github.com/Oboro-Dev/WindowPin) | macOS 14+, MIT | Explicit mirror explanation and permission guidance | Only one pin; not a superior replacement for Fuwa's multi-pin/freeze lifecycle. |
| [PiP](https://github.com/amitv87/PiP) | macOS, MIT | Local preview controls and separation of view/content | README discloses private PiP framework; broader media/AirPlay scope is unnecessary. |
| [OnTopReplica](https://github.com/LorenzCK/OnTopReplica) | Windows, MS-RL | Clear distinction between replica, click-through, and forwarding | DWM/.NET implementation and reciprocal license; not portable code. |
| [PowerToys Always On Top](https://learn.microsoft.com/en-us/windows/powertoys/always-on-top) | Windows, [MIT](https://github.com/microsoft/PowerToys/blob/main/LICENSE) | Discoverable toggle shortcut and visible pin state | Operates on real Windows windows, not ScreenCaptureKit mirrors. |

No single project is best in every dimension. Topit is the closest established product reference, PinWindow the closest menu-bar comparison, and PowerToys the strongest narrow reference for state feedback. Repository claims are reference material, not independent compatibility benchmarks.

## Chosen design

A larger native management window with a quiet sidebar, meaningful empty state and visible keyboard instructions; a compact left-click menu-bar panel for quick management; a native right-click menu for pin, settings, removal and quit. Keep existing app art, neutral system colors and SF Symbols. Do not add a brand color.

The main window must not offer a front-window button with no prepared target: becoming active loses that target. Direct users to the global shortcut in the source app. The menu-bar path continues to snapshot intent before activation.

Pin rows and floating controls expose freeze/resume and source actions with words, current state and disabled behavior. Mirror pixels remain click-through. A separate nonactivating control panel accepts only control interactions; source interaction is explicitly raising the actual source window. Closing/removing a pin never closes its source app.

Keep synchronous privacy/quit cleanup for both mirror and controls. Test source-closed and busy states, content sizing, menu availability, and control-panel teardown. Verify native rendering separately from automated model tests. Do not claim Windows support: Fuwa remains macOS 14+.

## Implementation refinement after native review

The management window includes an explicit searchable window picker, using the existing eligibility policy and exact window/PID confirmation before pinning. Already-pinned choices are disabled; selecting a stale choice must never toggle an existing pin off. The shortcut remains available for transient windows such as Quick Look. Launch shows the management window so a first launch has a visible destination.

## Local packaging incident and prevention

During QA, replacing only the executable and manually signing the host omitted the project's existing local-signing entitlements. The development copy aborted in dyld while loading Sparkle. The installed `/Applications/Fuwa.app` was untouched and was reopened successfully. Recovery used the complete `scripts/package-app.sh` flow, including framework loading validation. Do not substitute executable-copy/manual-sign shortcuts for this flow: `codesign --verify` alone does not establish runtime framework loading.

## Verification and boundaries

- Strict Swift build, core logic executable, and six initial native/model tests passed. Menu tests cover empty/closed-source availability and explicit Quit; termination tests cover synchronous hide/close.
- On the complete signed development bundle, native UI checks passed: main window, settings permissions, searchable window list, pinning a disposable TextEdit window, freeze, resume from floating controls, and reveal of the original TextEdit document. Exiting with a pin removed the development process. The full package's Sparkle runtime loading probe passed after the QA signing incident.
- User requested non-disruptive testing: the development process was stopped. Do not run interactive tests on their active desktop. Later checks used prohibited activation and never-visible native hosting windows; fixture renders are layout evidence, not live capture evidence.
- Background rendering covers English/Chinese empty and populated main windows, controls, tray, and dark appearance. Images in `dist/qa` are generated fixture artifacts, not committed screenshots of user windows.
- Control placement tests cover 100 source positions across primary, left, above, and offset-right displays, plus overlap selection and nearest-screen fallback.
- Actual display inventory on this machine still reports only the built-in display: 1512×982 points, 3024×1964 pixels, scale 2, no mirroring. User was asked whether the additional screen means a Mission Control Space or another display. No live secondary-display or Space isolation acceptance is claimed. Keyboard shortcut automation through app-directed Computer Use events is not a global-hotkey acceptance test.
- This is an isolated source change and local development package, not a new version/release or an installation over `/Applications/Fuwa.app`. Original checkout, Fuwa websites and Vido are untouched.
