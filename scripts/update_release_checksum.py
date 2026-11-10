#!/usr/bin/env python3
"""Update a version manifest with the SHA-256 of a built APK."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import stat
import tempfile
from pathlib import Path


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as apk:
        for chunk in iter(lambda: apk.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def update_manifest(apk_path: Path, manifest_path: Path) -> str:
    if not apk_path.is_file():
        raise FileNotFoundError(f"APK not found: {apk_path}")

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if not isinstance(manifest, dict):
        raise ValueError("Version manifest must be a JSON object")

    digest = sha256_file(apk_path)
    manifest["sha256"] = digest
    content = json.dumps(manifest, ensure_ascii=False, indent=2) + "\n"
    mode = stat.S_IMODE(manifest_path.stat().st_mode)

    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{manifest_path.name}.",
        suffix=".tmp",
        dir=manifest_path.parent,
    )
    try:
        os.fchmod(descriptor, mode)
        with os.fdopen(descriptor, "w", encoding="utf-8") as temporary:
            temporary.write(content)
            temporary.flush()
            os.fsync(temporary.fileno())
        os.replace(temporary_name, manifest_path)
    except Exception:
        try:
            os.unlink(temporary_name)
        except FileNotFoundError:
            pass
        raise

    return digest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk", type=Path, help="Built APK to hash")
    parser.add_argument(
        "manifest",
        nargs="?",
        type=Path,
        default=Path("version.json"),
        help="Version JSON to update (default: version.json)",
    )
    args = parser.parse_args()
    print(update_manifest(args.apk, args.manifest))


if __name__ == "__main__":
    main()
