import FuwaCore

func runFrozenFrameSizingTests(runner: inout LogicTestRunner) {
    runner.expect(
        FrozenFrameSizing.fittedDimensions(
            sourceWidth: 1_920,
            sourceHeight: 1_080,
            maxPixels: 4_000_000
        ) == PixelDimensions(width: 1_920, height: 1_080),
        "frozen frames below the pixel budget keep their native dimensions"
    )

    runner.expect(
        FrozenFrameSizing.fittedDimensions(
            sourceWidth: 2_000,
            sourceHeight: 2_000,
            maxPixels: 4_000_000
        ) == PixelDimensions(width: 2_000, height: 2_000),
        "frozen frames exactly at the pixel budget are not resampled"
    )

    let reduced = FrozenFrameSizing.fittedDimensions(
        sourceWidth: 6_000,
        sourceHeight: 4_000,
        maxPixels: 4_000_000
    )
    runner.expect(
        reduced == PixelDimensions(width: 2_449, height: 1_632),
        "oversized frozen frames are reduced proportionally"
    )
    runner.expect(
        (reduced?.pixelCount ?? .max) <= 4_000_000,
        "the reduced frozen frame never exceeds its pixel budget"
    )

    runner.expect(
        FrozenFrameSizing.fittedDimensions(
            sourceWidth: 1,
            sourceHeight: 10_000,
            maxPixels: 1
        ) == PixelDimensions(width: 1, height: 1),
        "extreme aspect ratios retain at least one pixel on each axis"
    )

    runner.expect(
        FrozenFrameSizing.fittedDimensions(
            sourceWidth: 10_000,
            sourceHeight: 1,
            maxPixels: 1
        ) == PixelDimensions(width: 1, height: 1),
        "extreme landscape frames also stay inside the pixel budget"
    )

    runner.expect(
        FrozenFrameSizing.fittedDimensions(
            sourceWidth: 0,
            sourceHeight: 1_080,
            maxPixels: 4_000_000
        ) == nil,
        "invalid source dimensions cannot produce a frozen frame size"
    )

    runner.expect(
        FrozenFrameSizing.fittedDimensions(
            sourceWidth: 1_920,
            sourceHeight: 1_080,
            maxPixels: 0
        ) == nil,
        "a non-positive pixel budget is rejected"
    )
}
