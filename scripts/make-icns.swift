#!/usr/bin/env swift

import Foundation

struct IconChunk {
    let type: String
    let filename: String
}

let chunks = [
    IconChunk(type: "ic11", filename: "icon_16x16@2x.png"),
    IconChunk(type: "ic12", filename: "icon_32x32@2x.png"),
    IconChunk(type: "ic13", filename: "icon_128x128@2x.png"),
    IconChunk(type: "ic14", filename: "icon_256x256@2x.png"),
    IconChunk(type: "ic10", filename: "icon_512x512@2x.png")
]

func appendBigEndian(_ value: UInt32, to data: inout Data) {
    var encoded = value.bigEndian
    withUnsafeBytes(of: &encoded) { bytes in
        data.append(contentsOf: bytes)
    }
}

guard CommandLine.arguments.count == 3 else {
    FileHandle.standardError.write(
        Data("Usage: make-icns.swift ICONSET_DIR OUTPUT.icns\n".utf8)
    )
    exit(64)
}

let iconsetURL = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
var payload = Data()

for chunk in chunks {
    let fileURL = iconsetURL.appendingPathComponent(chunk.filename)
    let png = try Data(contentsOf: fileURL)
    guard png.starts(with: [0x89, 0x50, 0x4E, 0x47]) else {
        throw CocoaError(.fileReadCorruptFile)
    }

    payload.append(contentsOf: chunk.type.utf8)
    appendBigEndian(UInt32(png.count + 8), to: &payload)
    payload.append(png)
}

var icns = Data("icns".utf8)
appendBigEndian(UInt32(payload.count + 8), to: &icns)
icns.append(payload)
try icns.write(to: outputURL, options: .atomic)
