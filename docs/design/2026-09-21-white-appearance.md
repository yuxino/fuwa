# White appearance and icon spacing

Fuwa uses an opaque white canvas, a pale neutral sidebar, and dark neutral primary actions. The management window, menu-bar panel, picker, settings and floating controls retain a light appearance in system Dark Mode. Existing selected, hover, pressed and disabled feedback remains in place. Settings sections use fine rules and space instead of thick gray bands.

The character remains Fuwa's existing white-haired portrait with violet eyes and an F clip. More white space reduces its visual density beside other Dock icons. `Resources/AppIcon.png` is the final master; `Resources/AppIcon.icns` and `docs/images/app-icon.png` are derived exports. The native export retains the previous master’s alpha silhouette, so the rounded corners remain consistent across sizes.

## Artwork provenance

Edited with the built-in image generation tool, using the previous `Resources/AppIcon.png` as the reference. Two transparent-background candidates were rejected because of defective edges. The accepted opaque artwork was exported through the existing rounded-square alpha silhouette before standard and Retina ICNS generation.

Final generation prompt:

> Edit this original icon artwork into a clean white icon. Keep original anime girl face, white hair, violet eyes, F clip and bow. Zoom out: girl portrait circle diameter 72% of full canvas width, centered. The background is SOLID PURE WHITE #FFFFFF across the ENTIRE SQUARE canvas. Important: do NOT remove background. NO TRANSPARENCY anywhere, NO alpha channel, NO grey, NO shadow, NO glow, NO rounded square frame. Fully opaque solid white square image with the original smaller anime portrait in its center. This is a flat 2D image, not a product mockup. White margin on all sides. 1024x1024 square.

## Verification

- Native English/Chinese offscreen renders, including a dark environment, were inspected.
- Installed management/settings and the window picker were checked on this Mac.
- Logic tests, strict compilation, native icon alpha geometry and standard/Retina representations passed.
- The universal package retains the existing local signing identity. This is a local preview of unreleased changes, not a new public release or a full updater-install acceptance run.
