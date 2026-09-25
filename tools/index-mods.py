#!/usr/bin/env python3
"""Index SoH HD/mod archives for PS5, where directory enumeration is unavailable."""
import argparse
from pathlib import Path


def archive_names(root):
    files = sorted((p for p in root.rglob("*") if p.is_file() and p.suffix.lower() in (".o2r", ".otr")),
                   key=lambda p: p.relative_to(root).as_posix())
    names = set()
    result = []
    for path in files:
        name = path.relative_to(root).as_posix()
        if path.stem in names:
            raise ValueError(f"Duplicate mod name {path.stem!r}; give each archive a unique filename")
        if any(c in name for c in "\r\n|\\\0") or name.startswith("#") or name != name.strip():
            raise ValueError(f"Filename cannot be represented in mods.txt: {name!r}")
        names.add(path.stem)
        result.append(name)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path, help="title's assets/mods directory")
    args = parser.parse_args()
    if not args.directory.is_dir():
        parser.error("directory does not exist")
    try:
        names = archive_names(args.directory)
    except ValueError as error:
        parser.error(str(error))
    (args.directory / "mods.txt").write_text("# SoH archives; paths relative to this directory.\n" +
                                              "".join(name + "\n" for name in names), encoding="utf-8")
    print(f"Indexed {len(names)} archive(s) in {args.directory / 'mods.txt'}")


if __name__ == "__main__":
    main()
