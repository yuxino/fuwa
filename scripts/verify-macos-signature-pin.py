#!/usr/bin/env python3
"""Verify Fuwa's embedded designated requirement in every Mach-O slice."""

from __future__ import annotations

import argparse
import hashlib
import json
import struct
from pathlib import Path


FAT_MAGIC = 0xCAFEBABE
FAT_MAGIC_64 = 0xCAFEBABF
MH_MAGIC_64 = 0xFEEDFACF
LC_CODE_SIGNATURE = 0x1D
CSMAGIC_EMBEDDED_SIGNATURE = 0xFADE0CC0
CSMAGIC_REQUIREMENTS = 0xFADE0C01
CSMAGIC_REQUIREMENT = 0xFADE0C00
CSSLOT_REQUIREMENTS = 2
DESIGNATED_REQUIREMENT_TYPE = 3
EXPECTED_ARCHITECTURES = {"arm64", "x86_64"}


def read_be32(data: bytes, offset: int) -> int:
    return struct.unpack_from(">I", data, offset)[0]


def read_blob(data: bytes, offset: int, expected_magic: int) -> bytes:
    actual_magic = read_be32(data, offset)
    if actual_magic != expected_magic:
        raise ValueError(
            f"unexpected code-signing blob magic 0x{actual_magic:08x}; "
            f"expected 0x{expected_magic:08x}"
        )
    length = read_be32(data, offset + 4)
    if length < 8 or offset + length > len(data):
        raise ValueError("code-signing blob length is outside its container")
    return data[offset : offset + length]


def read_superblob(
    data: bytes, offset: int, expected_magic: int
) -> dict[int, bytes]:
    outer = read_blob(data, offset, expected_magic)
    count = read_be32(outer, 8)
    if 12 + count * 8 > len(outer):
        raise ValueError("code-signing superblob index is truncated")

    entries: dict[int, bytes] = {}
    for index in range(count):
        slot, relative_offset = struct.unpack_from(">II", outer, 12 + index * 8)
        if slot in entries:
            raise ValueError(f"duplicate code-signing slot {slot}")
        entry_length = read_be32(outer, relative_offset + 4)
        if entry_length < 8 or relative_offset + entry_length > len(outer):
            raise ValueError(f"code-signing slot {slot} is outside its superblob")
        entries[slot] = outer[relative_offset : relative_offset + entry_length]
    return entries


def read_macho_slices(data: bytes) -> list[tuple[str, bytes]]:
    magic = read_be32(data, 0)
    if magic not in {FAT_MAGIC, FAT_MAGIC_64}:
        raise ValueError("release executable is not a universal Mach-O binary")

    count = read_be32(data, 4)
    entry_size = 20 if magic == FAT_MAGIC else 32
    if 8 + count * entry_size > len(data):
        raise ValueError("universal Mach-O header is truncated")

    slices: list[tuple[str, bytes]] = []
    for index in range(count):
        entry_offset = 8 + index * entry_size
        cpu_type = read_be32(data, entry_offset)
        if magic == FAT_MAGIC:
            slice_offset = read_be32(data, entry_offset + 8)
            slice_size = read_be32(data, entry_offset + 12)
        else:
            slice_offset, slice_size = struct.unpack_from(">QQ", data, entry_offset + 8)
        architecture = {
            0x01000007: "x86_64",
            0x0100000C: "arm64",
        }.get(cpu_type, f"cpu-0x{cpu_type:08x}")
        if slice_offset + slice_size > len(data):
            raise ValueError(f"{architecture} Mach-O slice is truncated")
        slices.append((architecture, data[slice_offset : slice_offset + slice_size]))
    return slices


def read_code_signature(macho: bytes) -> bytes:
    if len(macho) < 32 or struct.unpack_from("<I", macho, 0)[0] != MH_MAGIC_64:
        raise ValueError("expected a little-endian 64-bit Mach-O slice")

    command_count = struct.unpack_from("<I", macho, 16)[0]
    command_offset = 32
    for _ in range(command_count):
        if command_offset + 8 > len(macho):
            raise ValueError("Mach-O load commands are truncated")
        command, command_size = struct.unpack_from("<II", macho, command_offset)
        if command_size < 8 or command_offset + command_size > len(macho):
            raise ValueError("Mach-O load command has an invalid size")
        if command == LC_CODE_SIGNATURE:
            if command_size < 16:
                raise ValueError("LC_CODE_SIGNATURE is truncated")
            data_offset, data_size = struct.unpack_from("<II", macho, command_offset + 8)
            if data_offset + data_size > len(macho):
                raise ValueError("embedded code signature is outside its Mach-O slice")
            return macho[data_offset : data_offset + data_size]
        command_offset += command_size
    raise ValueError("Mach-O slice has no LC_CODE_SIGNATURE")


def designated_requirement_digest(macho: bytes) -> str:
    signature = read_code_signature(macho)
    signature_slots = read_superblob(signature, 0, CSMAGIC_EMBEDDED_SIGNATURE)
    if CSSLOT_REQUIREMENTS not in signature_slots:
        raise ValueError("embedded signature has no requirements slot")
    requirement_slots = read_superblob(
        signature_slots[CSSLOT_REQUIREMENTS], 0, CSMAGIC_REQUIREMENTS
    )
    if DESIGNATED_REQUIREMENT_TYPE not in requirement_slots:
        raise ValueError("embedded signature has no designated requirement")
    designated = requirement_slots[DESIGNATED_REQUIREMENT_TYPE]
    read_blob(designated, 0, CSMAGIC_REQUIREMENT)
    return hashlib.sha256(designated).hexdigest()


def load_expected_digest(path: Path) -> str:
    pins = json.loads(path.read_text(encoding="utf-8"))
    if pins.get("schemaVersion") != 1:
        raise ValueError("release signing pin file has an unsupported schema")
    digest = pins.get("identity", {}).get("designatedRequirementSha256", "")
    if not isinstance(digest, str) or len(digest) != 64:
        raise ValueError("release signing pin file has no SHA-256 requirement pin")
    try:
        bytes.fromhex(digest)
    except ValueError as error:
        raise ValueError("designated requirement pin is not hexadecimal") from error
    return digest.lower()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", type=Path, required=True)
    parser.add_argument("--pins", type=Path, required=True)
    arguments = parser.parse_args()

    expected_digest = load_expected_digest(arguments.pins)
    slices = read_macho_slices(arguments.binary.read_bytes())
    architectures = {architecture for architecture, _ in slices}
    if architectures != EXPECTED_ARCHITECTURES or len(slices) != 2:
        raise ValueError(
            "release executable must contain exactly arm64 and x86_64 slices; "
            f"found {sorted(architectures)}"
        )

    results: dict[str, str] = {}
    for architecture, macho in slices:
        digest = designated_requirement_digest(macho)
        if digest != expected_digest:
            raise ValueError(
                f"{architecture} designated requirement digest {digest} does not "
                f"match stable pin {expected_digest}"
            )
        results[architecture] = digest

    print(json.dumps({"schemaVersion": 1, "requirements": results}, sort_keys=True))


if __name__ == "__main__":
    main()
