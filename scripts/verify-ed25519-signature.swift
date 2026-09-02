#!/usr/bin/env swift

import CryptoKit
import Foundation

guard CommandLine.arguments.count == 4 else {
    FileHandle.standardError.write(
        Data("usage: verify-ed25519-signature.swift PUBLIC_KEY FILE SIGNATURE_FILE\n".utf8)
    )
    exit(2)
}

guard
    let publicKeyData = Data(base64Encoded: CommandLine.arguments[1]),
    let signatureText = try? String(
        contentsOfFile: CommandLine.arguments[3],
        encoding: .utf8
    ).trimmingCharacters(in: .whitespacesAndNewlines),
    let signature = Data(base64Encoded: signatureText),
    let fileData = FileManager.default.contents(atPath: CommandLine.arguments[2]),
    let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData),
    publicKey.isValidSignature(signature, for: fileData)
else {
    FileHandle.standardError.write(Data("signature verification failed\n".utf8))
    exit(1)
}
