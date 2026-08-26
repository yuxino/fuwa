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

let cornerAlpha = [
    alpha(x: 0, y: 0),
    alpha(x: width - 1, y: 0),
    alpha(x: 0, y: height - 1),
    alpha(x: width - 1, y: height - 1),
]
guard cornerAlpha.allSatisfy({ $0 <= 8 }) else {
    fail("AppIcon.png corners must be genuinely transparent, not painted black or checkerboard")
}
guard alpha(x: width / 2, y: height / 2) >= 247 else {
    fail("AppIcon.png center must remain opaque")
}

print("App icon alpha geometry is valid.")
