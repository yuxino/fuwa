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
    extractedDirectoryPath: String
) throws {
    let masterURL = URL(fileURLWithPath: masterPath)
    let sourceDirectory = URL(fileURLWithPath: sourceDirectoryPath, isDirectory: true)
    let extractedDirectory = URL(fileURLWithPath: extractedDirectoryPath, isDirectory: true)

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

    let roundedCornerAlpha = [
        master.sampledAlpha(xRatio: 0.10, yRatio: 0.10),
        master.sampledAlpha(xRatio: 0.90, yRatio: 0.10),
        master.sampledAlpha(xRatio: 0.10, yRatio: 0.90),
        master.sampledAlpha(xRatio: 0.90, yRatio: 0.90),
    ]
    try requireAppIcon(
        roundedCornerAlpha.allSatisfy({ $0 <= 8 }),
        "AppIcon.png must not contain an opaque outer matte around its rounded-square face"
    )

    let innerCornerAlpha = [
        master.sampledAlpha(xRatio: 0.15, yRatio: 0.15),
        master.sampledAlpha(xRatio: 0.85, yRatio: 0.15),
        master.sampledAlpha(xRatio: 0.15, yRatio: 0.85),
        master.sampledAlpha(xRatio: 0.85, yRatio: 0.85),
    ]
    try requireAppIcon(
        innerCornerAlpha.allSatisfy({ $0 >= 247 }),
        "AppIcon.png rounded-square face is too small or clipped"
    )

    var edgeTranslucentPixels = 0
    for y in 0..<master.height {
        for x in 0..<master.width {
            let value = master.alpha(x: x, y: y)
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
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024),
    ]

    for (filename, expectedSize) in expectedFiles {
        let sourceURL = sourceDirectory.appendingPathComponent(filename)
        let extractedURL = extractedDirectory.appendingPathComponent(filename)
        guard let source = decodeAppIcon(sourceURL) else {
            throw AppIconVerificationError(
                message: "unable to decode source representation \(filename)"
            )
        }
        guard let extracted = decodeAppIcon(extractedURL) else {
            throw AppIconVerificationError(
                message: "unable to decode extracted representation \(filename)"
            )
        }
        try requireAppIcon(
            source.width == expectedSize && source.height == expectedSize,
            "source representation \(filename) has the wrong dimensions"
        )
        try requireAppIcon(
            extracted.width == expectedSize && extracted.height == expectedSize,
            "extracted representation \(filename) has the wrong dimensions"
        )

        var totalDifference = 0
        var maximumDifference = 0
        for index in source.pixels.indices {
            let difference = abs(Int(source.pixels[index]) - Int(extracted.pixels[index]))
            totalDifference += difference
            maximumDifference = max(maximumDifference, difference)
        }
        let meanDifference = Double(totalDifference) / Double(source.pixels.count)
        try requireAppIcon(
            meanDifference <= 2.0 && maximumDifference <= 24,
            "ICNS round trip corrupted \(filename) "
                + "(mean pixel difference \(String(format: "%.2f", meanDifference)), "
                + "maximum \(maximumDifference))"
        )

        let center = ((expectedSize / 2) * expectedSize + expectedSize / 2) * 4
        try requireAppIcon(
            extracted.pixels[center + 3] >= 247,
            "extracted representation \(filename) lost its opaque center"
        )
    }
}

func verifyAppIconCommand(arguments: [String]) -> Never {
    guard arguments.count == 4 else {
        FileHandle.standardError.write(
            Data("error: usage: --verify-app-icon MASTER.png SOURCE.iconset EXTRACTED.iconset\n".utf8)
        )
        exit(64)
    }

    do {
        try verifyAppIcon(
            masterPath: arguments[1],
            sourceDirectoryPath: arguments[2],
            extractedDirectoryPath: arguments[3]
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
