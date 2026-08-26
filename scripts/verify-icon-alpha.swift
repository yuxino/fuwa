#!/usr/bin/env swift

import CoreGraphics
import Foundation
import ImageIO

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

guard CommandLine.arguments.count == 2 else {
    fail("usage: verify-icon-alpha.swift AppIcon.png")
}

let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
guard
    let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
    let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
else {
    fail("unable to decode \(sourceURL.path)")
}

let width = image.width
let height = image.height
let bytesPerRow = width * 4
var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)

guard let context = CGContext(
    data: &pixels,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: bytesPerRow,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        | CGBitmapInfo.byteOrder32Big.rawValue
) else {
    fail("unable to inspect icon pixels")
}

context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

func alpha(x: Int, y: Int) -> UInt8 {
    pixels[(y * bytesPerRow) + (x * 4) + 3]
}

func sampleAlpha(xRatio: Double, yRatio: Double) -> UInt8 {
    alpha(
        x: Int((Double(width - 1) * xRatio).rounded()),
        y: Int((Double(height - 1) * yRatio).rounded())
    )
}

let cornerAlpha = [
    alpha(x: 0, y: 0),
    alpha(x: width - 1, y: 0),
    alpha(x: 0, y: height - 1),
    alpha(x: width - 1, y: height - 1),
]
guard cornerAlpha.allSatisfy({ $0 <= 8 }) else {
    fail("AppIcon.png corners must be genuinely transparent, not painted black or checkerboard")
}
let roundedCornerAlpha = [
    sampleAlpha(xRatio: 0.10, yRatio: 0.10),
    sampleAlpha(xRatio: 0.90, yRatio: 0.10),
    sampleAlpha(xRatio: 0.10, yRatio: 0.90),
    sampleAlpha(xRatio: 0.90, yRatio: 0.90),
]
guard roundedCornerAlpha.allSatisfy({ $0 <= 8 }) else {
    fail("AppIcon.png must not contain an opaque outer matte around its rounded-square face")
}
let innerCornerAlpha = [
    sampleAlpha(xRatio: 0.15, yRatio: 0.15),
    sampleAlpha(xRatio: 0.85, yRatio: 0.15),
    sampleAlpha(xRatio: 0.15, yRatio: 0.85),
    sampleAlpha(xRatio: 0.85, yRatio: 0.85),
]
guard innerCornerAlpha.allSatisfy({ $0 >= 247 }) else {
    fail("AppIcon.png rounded-square face is too small or clipped")
}
var edgeTranslucentPixels = 0
for y in 0..<height {
    for x in 0..<width {
        let value = alpha(x: x, y: y)
        let isOuterBand = x < width / 5
            || x >= width - width / 5
            || y < height / 5
            || y >= height - height / 5
        if isOuterBand, value > 0, value < 255 {
            edgeTranslucentPixels += 1
        }
    }
}
guard edgeTranslucentPixels > 0 else {
    fail("AppIcon.png rounded edge must keep anti-aliasing")
}
guard alpha(x: width / 2, y: height / 2) >= 247 else {
    fail("AppIcon.png center must remain opaque")
}

print("App icon alpha geometry is valid.")
