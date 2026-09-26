#!/usr/bin/env python3
"""Record a locally rebuilt SDK's actual profile and refresh its integrity manifest."""
import argparse
import hashlib
import json
from pathlib import Path


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("sdk", type=Path)
    parser.add_argument("runtime_config", type=Path)
    parser.add_argument("height", type=int, choices=(1080, 1440, 2160))
    parser.add_argument("fps", type=int, choices=(60, 120))
    args = parser.parse_args()
    width = {1080: 1920, 1440: 2560, 2160: 3840}[args.height]
    config = args.runtime_config.read_text()
    for define in (f"-DPS5_SCANOUT_HEIGHT={args.height}", f"-DPS5_SCANOUT_FPS={args.fps}"):
        if define not in config.split():
            parser.error(f"Runtime does not match requested profile: {define}")
    profile = dict(width=width, height=args.height, fps=args.fps)
    header = "// Local SoH render/presentation profile; not negotiated HDMI status.\n#pragma once\n"
    header += "".join(f"#define PS5_OPENGL_NATIVE_{key.upper()} {value}\n" for key, value in profile.items())
    (args.sdk / "include/ps5_opengl_display.h").write_text(header)
    receipt = dict(display_profile=profile, hardware_validated=False,
                   runtime_sha256=digest(args.sdk / "lib/libps5_opengl_core33.a"),
                   runtime_config=config)
    (args.sdk / "share/soh-build-profile.json").write_text(json.dumps(receipt, indent=2) + "\n")
    files = sorted(p for p in args.sdk.rglob("*") if p.is_file() and p != args.sdk / "manifest.sha256")
    if any(p.is_symlink() for p in args.sdk.rglob("*")):
        parser.error("SDK must contain regular files/directories")
    (args.sdk / "manifest.sha256").write_text("".join(f"{digest(p)}  {p.relative_to(args.sdk).as_posix()}\n" for p in files))
    print(f"Recorded local SDK profile: {width}x{args.height}@{args.fps}")


if __name__ == "__main__":
    main()
