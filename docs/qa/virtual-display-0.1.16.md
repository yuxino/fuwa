# Virtual-display check: Fuwa 0.1.16

Date: 2026-09-23. Installed app: `/Applications/Fuwa.app`, version 0.1.16, build 17.

## Setup

One physical built-in Retina display, 1512×982 points at 2× scale. A temporary local AppKit fixture created a 1920×1080, non-HiDPI virtual display using the same private CoreGraphics interfaces documented in [DeskPad](https://github.com/Stengo/DeskPad). No virtual-display dependency was added to Fuwa. The fixture owned a counter window, move-to-display buttons, and a disconnect button.

CoreGraphics reported the virtual display as active at `(1512, 0, 1920, 1080)`. Active display count changed from 1 to 2, then back to 1 after removal. The fixture used a normal AppKit application event loop for functional checks; an earlier command-line probe cached an unchanged `NSScreen.screens` list despite CoreGraphics showing two active displays, so that probe alone was not used as application-level evidence.

## Observed through the installed app

- Fuwa's normal window picker listed the fixture window on the virtual display.
- Selecting it created one pin showing the live state.
- Moving the source to the built-in display and back retained the pin.
- Freezing switched the pin and its controls to the frozen state.
- Removing the virtual display left one active physical display. CoreGraphics then reported the visible frozen overlay at `(912, 370, 600, 432)` and its visible controls at `(1132, 292, 380, 67)`, both inside the remaining 1512×982 display (top-left coordinates).
- Selecting Resume switched the pin back to the live state.
- Unpinning returned Fuwa to zero pins. The fixture was quit and the system remained at one active display.

## Limits

These are native window/state and placement checks, not pixel-comparison results. The source counter was visible and advanced, but the captured overlay itself was not inspected frame by frame. No claim is made that mixed-scale sharpness, uninterrupted capture during movement, or all display arrangements were validated. Left/above/below removal and oversized-view behavior are covered by geometry regression tests, not native runs in this check. Physical cables, docks, external GPU/display drivers, and Intel hardware were not tested.

The existing 13 native regression tests and logic tests passed before release. Tag CI run: https://github.com/yuxino/fuwa/actions/runs/35818014006.
