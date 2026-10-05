#!/usr/bin/env python3
"""Validate optional PS5 mod archives and the manifest the port will use."""
import argparse
from pathlib import Path
import zipfile


def check_mods(title):
    bundled = title / "assets/mods/mods.txt"
    writable = title / "UserData/mods/mods.txt"
    manifest = writable if writable.is_file() else bundled
    if not manifest.is_file():
        for folder in (bundled.parent, writable.parent):
            if folder.is_dir() and any(p.is_file() and p.suffix.lower() in (".o2r", ".otr") for p in folder.rglob("*")):
                raise ValueError(f"mod archives in {folder} require mods.txt")
        return "no optional mods installed"
    names = set()
    count = 0
    for line in manifest.read_text(encoding="utf-8-sig").splitlines():
        line = line.lstrip("\ufeff").strip()
        if not line or line.startswith("#"):
            continue
        relative = Path(line)
        if relative.is_absolute() or ".." in relative.parts or any(c in line for c in "\\|\0"):
            raise ValueError(f"unsafe mod manifest entry: {line!r}")
        archive = manifest.parent / relative
        if archive.suffix not in (".o2r", ".otr") or not archive.is_file():
            raise ValueError(f"missing or unsupported mod archive: {archive}")
        if archive.stem in names:
            raise ValueError(f"duplicate mod name: {archive.stem}")
        names.add(archive.stem)
        if zipfile.is_zipfile(archive):
            with zipfile.ZipFile(archive) as z:
                bad = z.testzip()
                if bad:
                    raise ValueError(f"corrupt mod archive entry: {archive}: {bad}")
        elif archive.suffix == ".otr":
            with archive.open("rb") as stream:
                header = stream.read(32)
            if len(header) < 32 or header[:4] not in (b"MPQ\x1a", b"MPQ\x1b"):
                raise ValueError(f"invalid OTR/MPQ archive header: {archive}")
        else:
            raise ValueError(f"invalid O2R ZIP archive: {archive}")
        count += 1
    suffix = "; UserData manifest overrides bundled mods" if manifest == writable and bundled.is_file() else ""
    return f"{count} mod archive path(s) verified (ZIP CRC / MPQ header) using {manifest}{suffix}"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("title", type=Path)
    args = parser.parse_args()
    try:
        print(check_mods(args.title))
    except (OSError, ValueError, zipfile.BadZipFile) as error:
        parser.error(str(error))


if __name__ == "__main__":
    main()
