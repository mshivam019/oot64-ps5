#!/usr/bin/env bash
# Create oot.o2r from your own Ocarina of Time ROM with the official Ship of
# Harkinian Linux build, and copy it into output/PPSA99620/assets.
#
# Download the Ship of Harkinian 9.2.3 Linux build (soh.appimage) first.
#
#   ./tools/make-assets.sh --rom ~/oot.z64 --soh ~/soh.appimage
#   ./tools/make-assets.sh --rom ~/oot.z64 --soh ~/soh.appimage --skip-run
set -euo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
default_title=$(cd -- "$here/.." && pwd)/output/PPSA99620
title=$default_title
rom=
soh=
skip=
timeout=900

while [ $# -gt 0 ]; do
    case $1 in
        --rom) rom=${2:?--rom needs a path}; shift 2 ;;
        --soh) soh=${2:?--soh needs a path}; shift 2 ;;
        --title) title=${2:?--title needs a path}; shift 2 ;;
        --skip-run) skip=1; shift ;;
        --timeout) timeout=${2:?--timeout needs seconds}; shift 2 ;;
        -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
done

[ -n "$rom" ] || { echo "usage: make-assets.sh --rom <oot.z64> --soh <soh.appimage>" >&2; exit 2; }
[ -f "$rom" ] || { echo "ROM not found: $rom" >&2; exit 1; }
[ -f "$title/eboot.bin" ] || { echo "title folder not found at $title" >&2; exit 1; }

if [ -n "$soh" ] && [ -d "$soh" ]; then
    for candidate in soh.appimage soh AppRun; do
        if [ -e "$soh/$candidate" ]; then soh=$soh/$candidate; break; fi
    done
fi
[ -n "$soh" ] && [ -f "$soh" ] || { echo "Ship of Harkinian build not found; pass --soh <soh.appimage>" >&2; exit 1; }
chmod +x "$soh" 2>/dev/null || true
sohdir=$(cd -- "$(dirname -- "$soh")" && pwd)
soh=$sohdir/$(basename -- "$soh")
o2r=$sohdir/oot.o2r

echo "ROM:   $rom"
echo "soh:   $soh"
echo "title: $title"
echo

if [ ! -f "$o2r" ]; then
    if [ -n "$skip" ]; then echo "oot.o2r not found next to the SoH build and --skip-run was given" >&2; exit 1; fi
    # Ship of Harkinian looks for ROMs next to the AppImage, so put a copy there.
    romcopy=$sohdir/$(basename -- "$rom")
    if [ ! -e "$romcopy" ]; then
        cp -- "$rom" "$romcopy"
        trap 'rm -f -- "$romcopy"' EXIT
    fi
    # AppImages mount themselves with libfuse2, which newer distributions do not
    # install by default; unpack to a temporary folder instead when it is missing.
    if ! ldconfig -p 2>/dev/null | grep -q 'libfuse\.so\.2'; then
        export APPIMAGE_EXTRACT_AND_RUN=1
    fi
    echo "Launching Ship of Harkinian to extract oot.o2r; follow any prompts."
    echo "Close the game once it starts."
    (cd "$sohdir" && exec "$soh") >/dev/null 2>&1 &
    pid=$!
    deadline=$(( $(date +%s) + timeout ))
    while [ ! -f "$o2r" ] && [ "$(date +%s)" -lt "$deadline" ]; do
        kill -0 "$pid" 2>/dev/null ||
            { echo "Ship of Harkinian exited before creating oot.o2r" >&2; exit 1; }
        sleep 2
    done
    # The archive appears as soon as extraction starts; wait until its size settles.
    last=-1
    while [ -f "$o2r" ] && [ "$(date +%s)" -lt "$deadline" ]; do
        size=$(stat -c%s "$o2r")
        [ "$size" = "$last" ] && break
        last=$size
        sleep 3
    done
fi

[ -f "$o2r" ] || { echo "oot.o2r was not created within ${timeout}s" >&2; exit 1; }
[ "$(head -c2 "$o2r")" = "PK" ] || { echo "oot.o2r does not look like a valid archive: $o2r" >&2; exit 1; }
if command -v unzip >/dev/null 2>&1; then
    unzip -tqq "$o2r" >/dev/null 2>&1 ||
        { echo "oot.o2r is incomplete or corrupt ($o2r); delete it and run again" >&2; exit 1; }
fi

mkdir -p "$title/assets"
cp -f "$o2r" "$title/assets/oot.o2r"
echo "Copied oot.o2r into $title/assets"
for name in soh.o2r gamecontrollerdb.txt; do
    [ -e "$title/assets/$name" ] || echo "warning: missing $title/assets/$name"
done
echo "Next: copy output/PPSA99620 to the console (see INSTALL.txt)."
