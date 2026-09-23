# Mixed-scale capture regression, 2026-09-23

One physical built-in Retina screen (1512×982 points, 2×), plus a temporary virtual screen (1920×1080, 1×) to its right. Source: the disposable counter fixture. Tests imported Fuwa's actual `PinSession`, `TargetResolver`, and `CaptureView` into the native test host; they did not run the installed application binary or replace its permissions. No screenshot-sharing protections were changed.

## Reproduced defect

Starting capture on Retina and moving the source to the 1× display left the capture configured at 1200×864 pixels. The source content occupied only 600×432 pixels in its upper-left corner. The counter still advanced, so the earlier installed-app state checks did not catch this. See [the captured buffer](before-1x.png), step 18 in [the original trace](before-frames.tsv). Freezing and resuming rebuilt the filter and happened to restore the proper size.

`SCContentFilter.pointPixelScale` remained the initial value. The fix reads `SCStreamFrameInfo.scaleFactor` from complete incoming frames, updates the capture configuration on changes, and sets `scalesToFit` during the transition. SDK documentation defines that attachment as the current display's pixel-to-point factor (1–4). Invalid or missing metadata is ignored.

## Verification

[The post-fix trace](frames.tsv) contains 40 samples. Actual source coordinates, not button clicks alone, establish which screen was used:

- Steps 0–4: main display, 1200×864.
- Steps 5–14: virtual display, 600×432; counter advances and the image fills the canvas. [Example](after-1x.png).
- Steps 15–24: main display again, 1200×864. [Example](after-2x.png).
- Steps 25–29: frozen; raw pixel data is identical across all five samples even while the source counter continues.
- Steps 30–33: resumed on virtual display, 600×432; new counter values arrive.
- Step 34: first sample after virtual-display removal is on the main display but still 600×432 while the configuration update settles.
- Steps 35–39: main display, 1200×864; counter continues. Sampling does not establish the exact transition duration.

The native integration test passed in 88.4 seconds. It checks captured text, changing live content, canvas interior alpha, and frozen pixel equality. Unit coverage also checks missing, invalid, and changing frame scale metadata. Full ordinary native and logic regression runs passed; the interactive probe is explicitly disabled during ordinary CI.

Reproduction fixture and commands: [scripts/qa/virtual-display](../../../scripts/qa/virtual-display/README.md).

## Installed application

The stable-signed Universal 0.1.17 (build 18) was installed at `/Applications/Fuwa.app` and launched. Through its normal UI, the virtual-screen fixture was selected, pinned, moved between displays, frozen on the virtual display, resumed after disconnecting that display, and unpinned. The app returned to zero pins; the fixture was quit. These are installed-app interaction checks; the pixel evidence above comes from the native test host.

## Limits

Captured buffers verify the capture pipeline, not the final screen compositor. Sampling every two seconds does not measure frame pacing or rule out a brief transition artifact. This run used a right-side virtual display only; it does not certify all positions, physical cables/docks, display-driver behavior, Intel hardware, or an updater installation. The original installed-app placement checks are documented separately in [the 0.1.16 report](../virtual-display-0.1.16.md). All fixture windows and the virtual display were removed afterward.
