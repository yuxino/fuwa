#!/usr/bin/env swift

import CoreGraphics
import Foundation
import ImageIO

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

struct DecodedImage {
    let width: Int
    let height: Int
    let pixels: [UInt8]
}

func decode(_ url: URL) -> DecodedImage? {
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
    return DecodedImage(width: image.width, height: image.height, pixels: pixels)
}

guard CommandLine.arguments.count == 3 else {
    fail("usage: verify-icon-roundtrip.swift SOURCE.iconset EXTRACTED.iconset")
}

let sourceDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let extractedDirectory = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
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
    guard let source = decode(sourceURL) else {
        fail("unable to decode source representation \(filename)")
    }
    guard let extracted = decode(extractedURL) else {
        fail("unable to decode extracted representation \(filename)")
    }
    guard source.width == expectedSize, source.height == expectedSize else {
        fail("source representation \(filename) has the wrong dimensions")
    }
    guard extracted.width == expectedSize, extracted.height == expectedSize else {
        fail("extracted representation \(filename) has the wrong dimensions")
    }

    var totalDifference = 0
    var maximumDifference = 0
    for index in source.pixels.indices {
        let difference = abs(Int(source.pixels[index]) - Int(extracted.pixels[index]))
        totalDifference += difference
        maximumDifference = max(maximumDifference, difference)
    }
    let meanDifference = Double(totalDifference) / Double(source.pixels.count)
    guard meanDifference <= 2.0, maximumDifference <= 24 else {
        fail(
            "ICNS round trip corrupted \(filename) "
                + "(mean pixel difference \(String(format: "%.2f", meanDifference)), "
                + "maximum \(maximumDifference))"
        )
    }

    let center = ((expectedSize / 2) * expectedSize + expectedSize / 2) * 4
    guard extracted.pixels[center + 3] >= 247 else {
        fail("extracted representation \(filename) lost its opaque center")
    }
}

print("All standard and Retina ICNS representations survive a pixel round trip.")
