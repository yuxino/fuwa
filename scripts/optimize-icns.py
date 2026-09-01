#!/usr/bin/env python3

from __future__ import annotations

import binascii
import os
from pathlib import Path
import stat
import struct
import sys
import tempfile
import zlib


PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
ICNS_HEADER_SIZE = 8
PNG_COMPRESSION_LEVEL = 8


def read_u32(data: bytes, offset: int) -> int:
    if offset + 4 > len(data):
        raise ValueError("truncated 32-bit field")
    return struct.unpack_from(">I", data, offset)[0]


def make_png_chunk(kind: bytes, payload: bytes) -> bytes:
    checksum = binascii.crc32(kind + payload) & 0xFFFFFFFF
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", checksum)


def recompress_png(data: bytes) -> bytes:
    if not data.startswith(PNG_SIGNATURE):
        return data

    chunks: list[tuple[bytes, bytes, bytes]] = []
    idat_payload = bytearray()
    first_idat_index: int | None = None
    offset = len(PNG_SIGNATURE)
    while offset < len(data):
        payload_size = read_u32(data, offset)
        end = offset + 12 + payload_size
        if end > len(data):
            raise ValueError("truncated PNG chunk")
        kind = data[offset + 4 : offset + 8]
        payload = data[offset + 8 : offset + 8 + payload_size]
        encoded = data[offset:end]
        expected_checksum = read_u32(data, offset + 8 + payload_size)
        actual_checksum = binascii.crc32(kind + payload) & 0xFFFFFFFF
        if actual_checksum != expected_checksum:
            raise ValueError(f"invalid PNG checksum for {kind!r}")
        if kind == b"IDAT":
            if first_idat_index is None:
                first_idat_index = len(chunks)
            idat_payload.extend(payload)
        else:
            chunks.append((kind, payload, encoded))
        offset = end

    if offset != len(data) or first_idat_index is None:
        raise ValueError("PNG has no valid IDAT payload")
    if not chunks or chunks[0][0] != b"IHDR" or chunks[-1][0] != b"IEND":
        raise ValueError("PNG chunk order is invalid")

    filtered_pixels = zlib.decompress(bytes(idat_payload))
    compressed = zlib.compress(filtered_pixels, PNG_COMPRESSION_LEVEL)
    if len(compressed) >= len(idat_payload):
        return data

    encoded_chunks: list[bytes] = []
    for index, (_, _, encoded) in enumerate(chunks):
        if index == first_idat_index:
            encoded_chunks.append(make_png_chunk(b"IDAT", compressed))
        encoded_chunks.append(encoded)
    return PNG_SIGNATURE + b"".join(encoded_chunks)


def optimize_icns(data: bytes) -> tuple[bytes, int]:
    if len(data) < ICNS_HEADER_SIZE or data[:4] != b"icns":
        raise ValueError("input is not an ICNS file")
    if read_u32(data, 4) != len(data):
        raise ValueError("ICNS length does not match file size")

    entries: list[bytes] = []
    optimized_png_count = 0
    offset = ICNS_HEADER_SIZE
    while offset < len(data):
        if offset + ICNS_HEADER_SIZE > len(data):
            raise ValueError("truncated ICNS entry")
        kind = data[offset : offset + 4]
        entry_size = read_u32(data, offset + 4)
        if entry_size < ICNS_HEADER_SIZE or offset + entry_size > len(data):
            raise ValueError("invalid ICNS entry length")
        payload = data[offset + ICNS_HEADER_SIZE : offset + entry_size]
        optimized_payload = recompress_png(payload)
        if len(optimized_payload) < len(payload):
            optimized_png_count += 1
        entries.append(
            kind
            + struct.pack(">I", ICNS_HEADER_SIZE + len(optimized_payload))
            + optimized_payload
        )
        offset += entry_size

    total_size = ICNS_HEADER_SIZE + sum(len(entry) for entry in entries)
    return b"icns" + struct.pack(">I", total_size) + b"".join(entries), optimized_png_count


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: optimize-icns.py <AppIcon.icns>", file=sys.stderr)
        return 64

    path = Path(sys.argv[1])
    original_mode = stat.S_IMODE(path.stat().st_mode)
    original = path.read_bytes()
    optimized, optimized_png_count = optimize_icns(original)
    if len(optimized) > len(original):
        raise ValueError("optimized ICNS unexpectedly grew")

    with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as temporary:
        temporary.write(optimized)
        temporary_path = Path(temporary.name)
    os.chmod(temporary_path, original_mode)
    os.replace(temporary_path, path)
    print(
        f"Optimized {optimized_png_count} ICNS PNG payloads: "
        f"{len(original)} -> {len(optimized)} bytes."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
