import CoreGraphics
import Darwin
import Foundation
import ImageIO

private struct AppIconVerificationError: LocalizedError {
    let message: String

    var errorDescription: String? { message }
}

private struct DecodedAppIcon {
    let width: Int
    let height: Int
    let pixels: [UInt8]

    func alpha(x: Int, y: Int) -> UInt8 {
        pixels[((y * width) + x) * 4 + 3]
    }

    func sampledAlpha(xRatio: Double, yRatio: Double) -> UInt8 {
        alpha(
            x: Int((Double(width - 1) * xRatio).rounded()),
            y: Int((Double(height - 1) * yRatio).rounded())
        )
    }
}

private func decodeAppIcon(_ url: URL) -> DecodedAppIcon? {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        return nil
    }

    return decodeAppIcon(image)
}

private func decodeAppIcon(_ image: CGImage) -> DecodedAppIcon? {
    let bytesPerRow = image.width * 4
    var pixels = [UInt8](repeating: 0, count: bytesPerRow * image.height)
    guard let context = CGContext(
        data: &pixels,
        width: image.width,
        height: image.height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.byteOrder32Big.rawValue
    ) else {
        return nil
    }
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    return DecodedAppIcon(width: image.width, height: image.height, pixels: pixels)
}

private func requireAppIcon(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else { throw AppIconVerificationError(message: message) }
}

private func verifyAppIcon(
    masterPath: String,
    sourceDirectoryPath: String,
    icnsPath: String
) throws {
    let masterURL = URL(fileURLWithPath: masterPath)
    let sourceDirectory = URL(fileURLWithPath: sourceDirectoryPath, isDirectory: true)
    let icnsURL = URL(fileURLWithPath: icnsPath)

    guard let master = decodeAppIcon(masterURL) else {
        throw AppIconVerificationError(message: "unable to decode \(masterURL.path)")
    }

    let cornerAlpha = [
        master.alpha(x: 0, y: 0),
        master.alpha(x: master.width - 1, y: 0),
        master.alpha(x: 0, y: master.height - 1),
        master.alpha(x: master.width - 1, y: master.height - 1),
    ]
    try requireAppIcon(
        cornerAlpha.allSatisfy({ $0 <= 8 }),
        "AppIcon.png corners must be genuinely transparent, not painted black or checkerboard"
    )

    let outsideCircleAlpha = [
        master.sampledAlpha(xRatio: 0.15, yRatio: 0.15),
        master.sampledAlpha(xRatio: 0.85, yRatio: 0.15),
        master.sampledAlpha(xRatio: 0.15, yRatio: 0.85),
        master.sampledAlpha(xRatio: 0.85, yRatio: 0.85),
    ]
    try requireAppIcon(
        outsideCircleAlpha.allSatisfy({ $0 <= 8 }),
        "AppIcon.png must not contain an opaque outer matte around its circular portrait"
    )

    let insideCircleAlpha = [
        master.sampledAlpha(xRatio: 0.20, yRatio: 0.20),
        master.sampledAlpha(xRatio: 0.80, yRatio: 0.20),
        master.sampledAlpha(xRatio: 0.20, yRatio: 0.80),
        master.sampledAlpha(xRatio: 0.80, yRatio: 0.80),
    ]
    try requireAppIcon(
        insideCircleAlpha.allSatisfy({ $0 >= 247 }),
        "AppIcon.png circular portrait is too small or clipped"
    )

    var edgeTranslucentPixels = 0
    let centerX = Double(master.width - 1) / 2
    let centerY = Double(master.height - 1) / 2
    let exteriorRadius = Double(min(master.width, master.height)) * 0.49
    for y in 0..<master.height {
        for x in 0..<master.width {
            let value = master.alpha(x: x, y: y)
            if hypot(Double(x) - centerX, Double(y) - centerY) >= exteriorRadius {
                try requireAppIcon(
                    value <= 8,
                    "AppIcon.png pixels outside its circular portrait must be transparent"
                )
            }
            let isOuterBand = x < master.width / 5
                || x >= master.width - master.width / 5
                || y < master.height / 5
                || y >= master.height - master.height / 5
            if isOuterBand, value > 0, value < 255 {
                edgeTranslucentPixels += 1
            }
        }
    }
    try requireAppIcon(
        edgeTranslucentPixels > 0,
        "AppIcon.png rounded edge must keep anti-aliasing"
    )
    try requireAppIcon(
        master.alpha(x: master.width / 2, y: master.height / 2) >= 247,
        "AppIcon.png center must remain opaque"
    )

    let expectedFiles = [
        ("icon_16x16.png", 16, 72),
        ("icon_16x16@2x.png", 32, 144),
        ("icon_32x32.png", 32, 72),
        ("icon_32x32@2x.png", 64, 144),
        ("icon_128x128.png", 128, 72),
        ("icon_128x128@2x.png", 256, 144),
        ("icon_256x256.png", 256, 72),
        ("icon_256x256@2x.png", 512, 144),
        ("icon_512x512.png", 512, 72),
        ("icon_512x512@2x.png", 1024, 144),
    ]

    // iconutil's PNG export can brighten translucent pixels in ic04/ic05 entries.
    // Validate the final ICNS directly, without that export conversion.
    guard let icnsSource = CGImageSourceCreateWithURL(icnsURL as CFURL, nil) else {
        throw AppIconVerificationError(message: "unable to read \(icnsURL.path)")
    }
    let representationCount = CGImageSourceGetCount(icnsSource)
    try requireAppIcon(
        representationCount == expectedFiles.count,
        "ICNS must contain all 10 standard and Retina representations"
    )
    let representationProperties = (0..<representationCount).map {
        CGImageSourceCopyPropertiesAtIndex(icnsSource, $0, nil) as? [CFString: Any]
    }
    var verifiedIndexes = Set<Int>()

    for (filename, expectedSize, expectedDPI) in expectedFiles {
        let sourceURL = sourceDirectory.appendingPathComponent(filename)
        guard let source = decodeAppIcon(sourceURL) else {
            throw AppIconVerificationError(
                message: "unable to decode source representation \(filename)"
            )
        }
        let matchingIndexes = representationProperties.indices.filter { index in
            guard let properties = representationProperties[index] else { return false }
            return (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue
                == Double(expectedSize)
                && (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue
                    == Double(expectedSize)
                && (properties[kCGImagePropertyDPIWidth] as? NSNumber)?.doubleValue
                    == Double(expectedDPI)
                && (properties[kCGImagePropertyDPIHeight] as? NSNumber)?.doubleValue
                    == Double(expectedDPI)
        }
        try requireAppIcon(
            matchingIndexes.count == 1,
            "ICNS must contain exactly one \(filename) representation at \(expectedDPI) DPI"
        )
        let representationIndex = matchingIndexes[0]
        try requireAppIcon(
            verifiedIndexes.insert(representationIndex).inserted,
            "ICNS representation \(filename) was already verified"
        )
        guard
            let image = CGImageSourceCreateImageAtIndex(icnsSource, representationIndex, nil),
            let generated = decodeAppIcon(image)
        else {
            throw AppIconVerificationError(
                message: "unable to decode ICNS representation \(filename)"
            )
        }
        try requireAppIcon(
            source.width == expectedSize && source.height == expectedSize,
            "source representation \(filename) has the wrong dimensions"
        )
        try requireAppIcon(
            generated.width == expectedSize && generated.height == expectedSize,
            "ICNS representation \(filename) has the wrong dimensions"
        )

        var totalDifference = 0
        var maximumDifference = 0
        for index in source.pixels.indices {
            let difference = abs(Int(source.pixels[index]) - Int(generated.pixels[index]))
            totalDifference += difference
            maximumDifference = max(maximumDifference, difference)
        }
        let meanDifference = Double(totalDifference) / Double(source.pixels.count)
        try requireAppIcon(
            meanDifference <= 2.0 && maximumDifference <= 24,
            "ICNS representation differs from \(filename) "
                + "(mean pixel difference \(String(format: "%.2f", meanDifference)), "
                + "maximum \(maximumDifference))"
        )

        let center = ((expectedSize / 2) * expectedSize + expectedSize / 2) * 4
        try requireAppIcon(
            generated.pixels[center + 3] >= 247,
            "ICNS representation \(filename) lost its opaque center"
        )
    }
    try requireAppIcon(
        verifiedIndexes.count == representationCount,
        "ICNS contains an unverified representation"
    )
}

func verifyAppIconCommand(arguments: [String]) -> Never {
    guard arguments.count == 4 else {
        FileHandle.standardError.write(
            Data("error: usage: --verify-app-icon MASTER.png SOURCE.iconset ICON.icns\n".utf8)
        )
        exit(64)
    }

    do {
        try verifyAppIcon(
            masterPath: arguments[1],
            sourceDirectoryPath: arguments[2],
            icnsPath: arguments[3]
        )
        print("App icon alpha geometry and all standard and Retina representations are valid.")
        exit(0)
    } catch {
        FileHandle.standardError.write(
            Data("error: \(error.localizedDescription)\n".utf8)
        )
        exit(1)
    }
}
