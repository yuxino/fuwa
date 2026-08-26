#!/usr/bin/env swift

import CoreGraphics
import Foundation
import ImageIO

enum IconPayload {
    case png(String)
    case legacyRGB(String, size: Int)
    case legacyAlpha(String, size: Int)
}

struct IconChunk {
    let type: String
    let payload: IconPayload
}

struct RGBAImage {
    let width: Int
    let height: Int
    let red: [UInt8]
    let green: [UInt8]
    let blue: [UInt8]
    let alpha: [UInt8]
}

let chunks = [
    IconChunk(type: "is32", payload: .legacyRGB("icon_16x16.png", size: 16)),
    IconChunk(type: "s8mk", payload: .legacyAlpha("icon_16x16.png", size: 16)),
    IconChunk(type: "ic11", payload: .png("icon_16x16@2x.png")),
    IconChunk(type: "il32", payload: .legacyRGB("icon_32x32.png", size: 32)),
    IconChunk(type: "l8mk", payload: .legacyAlpha("icon_32x32.png", size: 32)),
    IconChunk(type: "ic12", payload: .png("icon_32x32@2x.png")),
    IconChunk(type: "ic07", payload: .png("icon_128x128.png")),
    IconChunk(type: "ic13", payload: .png("icon_128x128@2x.png")),
    IconChunk(type: "ic08", payload: .png("icon_256x256.png")),
    IconChunk(type: "ic14", payload: .png("icon_256x256@2x.png")),
    IconChunk(type: "ic09", payload: .png("icon_512x512.png")),
    IconChunk(type: "ic10", payload: .png("icon_512x512@2x.png")),
]

func appendBigEndian(_ value: UInt32, to data: inout Data) {
    var encoded = value.bigEndian
    withUnsafeBytes(of: &encoded) { bytes in
        data.append(contentsOf: bytes)
    }
}

func decodePNG(at url: URL, expectedSize: Int) throws -> RGBAImage {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
        image.width == expectedSize,
        image.height == expectedSize
    else {
        throw CocoaError(.fileReadCorruptFile)
    }

    let bytesPerRow = expectedSize * 4
    var pixels = [UInt8](repeating: 0, count: bytesPerRow * expectedSize)
    guard let context = CGContext(
        data: &pixels,
        width: expectedSize,
        height: expectedSize,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.byteOrder32Big.rawValue
    ) else {
        throw CocoaError(.fileWriteUnknown)
    }
    context.draw(image, in: CGRect(x: 0, y: 0, width: expectedSize, height: expectedSize))

    var red = [UInt8]()
    var green = [UInt8]()
    var blue = [UInt8]()
    var alpha = [UInt8]()
    let pixelCount = expectedSize * expectedSize
    red.reserveCapacity(pixelCount)
    green.reserveCapacity(pixelCount)
    blue.reserveCapacity(pixelCount)
    alpha.reserveCapacity(pixelCount)

    for index in 0..<pixelCount {
        let offset = index * 4
        let pixelAlpha = Int(pixels[offset + 3])
        alpha.append(UInt8(pixelAlpha))
        guard pixelAlpha > 0 else {
            red.append(0)
            green.append(0)
            blue.append(0)
            continue
        }

        func unpremultiply(_ value: UInt8) -> UInt8 {
            UInt8(min(255, (Int(value) * 255 + pixelAlpha / 2) / pixelAlpha))
        }
        red.append(unpremultiply(pixels[offset]))
        green.append(unpremultiply(pixels[offset + 1]))
        blue.append(unpremultiply(pixels[offset + 2]))
    }

    return RGBAImage(
        width: expectedSize,
        height: expectedSize,
        red: red,
        green: green,
        blue: blue,
        alpha: alpha
    )
}

func encodeLegacyChannel(_ values: [UInt8]) -> Data {
    var encoded = Data()
    var index = 0

    while index < values.count {
        var repeated = 1
        while index + repeated < values.count,
              values[index + repeated] == values[index],
              repeated < 130 {
            repeated += 1
        }

        if repeated >= 3 {
            encoded.append(UInt8(0x80 | (repeated - 3)))
            encoded.append(values[index])
            index += repeated
            continue
        }

        let literalStart = index
        index += repeated
        while index < values.count, index - literalStart < 128 {
            var nextRepeated = 1
            while index + nextRepeated < values.count,
                  values[index + nextRepeated] == values[index],
                  nextRepeated < 3 {
                nextRepeated += 1
            }
            if nextRepeated >= 3 {
                break
            }
            let available = min(nextRepeated, 128 - (index - literalStart))
            index += available
            if available < nextRepeated {
                break
            }
        }

        let literalCount = index - literalStart
        encoded.append(UInt8(literalCount - 1))
        encoded.append(contentsOf: values[literalStart..<index])
    }

    return encoded
}

guard CommandLine.arguments.count == 3 else {
    FileHandle.standardError.write(
        Data("Usage: make-icns.swift ICONSET_DIR OUTPUT.icns\n".utf8)
    )
    exit(64)
}

let iconsetURL = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
var decodedImages = [String: RGBAImage]()

func decodedImage(filename: String, size: Int) throws -> RGBAImage {
    if let existing = decodedImages[filename] {
        return existing
    }
    let image = try decodePNG(
        at: iconsetURL.appendingPathComponent(filename),
        expectedSize: size
    )
    decodedImages[filename] = image
    return image
}

var payload = Data()
for chunk in chunks {
    let chunkPayload: Data
    switch chunk.payload {
    case let .png(filename):
        let fileURL = iconsetURL.appendingPathComponent(filename)
        let png = try Data(contentsOf: fileURL)
        guard png.starts(with: [0x89, 0x50, 0x4E, 0x47]) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        chunkPayload = png
    case let .legacyRGB(filename, size):
        let image = try decodedImage(filename: filename, size: size)
        var rgb = encodeLegacyChannel(image.red)
        rgb.append(encodeLegacyChannel(image.green))
        rgb.append(encodeLegacyChannel(image.blue))
        chunkPayload = rgb
    case let .legacyAlpha(filename, size):
        chunkPayload = Data(try decodedImage(filename: filename, size: size).alpha)
    }

    guard chunk.type.utf8.count == 4 else {
        throw CocoaError(.fileWriteInvalidFileName)
    }
    payload.append(contentsOf: chunk.type.utf8)
    appendBigEndian(UInt32(chunkPayload.count + 8), to: &payload)
    payload.append(chunkPayload)
}

var icns = Data("icns".utf8)
appendBigEndian(UInt32(payload.count + 8), to: &icns)
icns.append(payload)
try icns.write(to: outputURL, options: .atomic)
