#!/usr/bin/env python3
"""Verify Android native ELF LOAD segments use 16 KB-compatible alignment."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
import zipfile
from pathlib import PurePosixPath


def parse_load_segments(output: str) -> list[tuple[int, int, int]]:
    segments: list[tuple[int, int, int]] = []
    for line in output.splitlines():
        parts = line.split()
        if not parts or parts[0] != "LOAD":
            continue
        if len(parts) < 8:
            raise ValueError(f"Could not parse ELF LOAD segment: {line}")
        offset = int(parts[1], 16)
        virtual_address = int(parts[2], 16)
        alignment = int(parts[-1], 16)
        segments.append((offset, virtual_address, alignment))
    return segments


def verify_archive(archive_path: str, readelf: str, min_alignment: int) -> int:
    errors = 0
    checked = 0
    with zipfile.ZipFile(archive_path) as archive:
        native_entries = [
            info for info in archive.infolist()
            if info.filename.endswith(".so")
            and ("/lib/" in f"/{info.filename}" or info.filename.startswith("lib/"))
        ]
        if not native_entries:
            print(f"ERROR: No native .so libraries found in {archive_path}")
            return 1

        for info in native_entries:
            checked += 1
            data = archive.read(info)
            temp_name = f"/tmp/vokey_16kb_{checked}.so"
            with open(temp_name, "wb") as output:
                output.write(data)

            result = subprocess.run(
                [readelf, "-lW", temp_name],
                check=False,
                capture_output=True,
                text=True,
            )
            if result.returncode != 0:
                print(f"ERROR: readelf failed for {info.filename}: {result.stderr}")
                errors += 1
                continue

            try:
                segments = parse_load_segments(result.stdout)
            except (ValueError, IndexError) as error:
                print(f"ERROR: {info.filename}: {error}")
                errors += 1
                continue

            if not segments:
                print(f"ERROR: {info.filename}: no LOAD segments found")
                errors += 1
                continue

            failures = []
            for offset, virtual_address, alignment in segments:
                if alignment < min_alignment:
                    failures.append(
                        f"p_align=0x{alignment:x} (requires >=0x{min_alignment:x})"
                    )
                if offset % min_alignment != virtual_address % min_alignment:
                    failures.append(
                        "p_offset and p_vaddr are not congruent modulo 16 KB"
                    )

            if failures:
                print(f"FAIL: {info.filename}: {'; '.join(failures)}")
                errors += 1
            else:
                print(f"PASS: {info.filename} ({len(segments)} LOAD segments)")

    print(
        f"Checked {checked} native libraries in {archive_path}; "
        f"{errors} library/libraries failed 16 KB alignment."
    )
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--archive", required=True, help="APK or AAB archive to inspect")
    parser.add_argument("--readelf", required=True, help="Android NDK llvm-readelf path")
    args = parser.parse_args()
    return 1 if verify_archive(args.archive, args.readelf, 16_384) else 0


if __name__ == "__main__":
    sys.exit(main())
