#!/usr/bin/env bash
# One command from your own Ocarina of Time ROM to a distributable Ship of
# Harkinian (PPSA99620) package.
#
#   mkdir -p rom && cp /path/to/oot.z64 rom/oot.z64
#   tools/release.sh
#
# The ROM can also be passed as the first argument or set in $SOH_ROM. The
# default build uses the stock 1080p60 SDK; pass --profile for a matched
# GL/SDL build (tools/build-profile.sh).
#
#   tools/release.sh /path/to/oot.z64 --profile 2160p120
#   tools/release.sh --from-dir /opt/ps5sdk/build/soh-2160p120/dist/PPSA99620
#   tools/release.sh --with-assets            # include ROM-derived .o2r (private)
#   tools/release.sh --variant camera-controls --profile 2160p120
#   tools/release.sh --platform windows       # one platform (default: windows + linux)
set -euo pipefail
source "$(dirname "$0")/env.sh"

TITLE_ID=PPSA99620
export PS5_SDL2_PREFIX=${PS5_SDL2_PREFIX:-$PS5_OPENGL_ROOT/build/sdl2-native/sdk}

ROM=${SOH_ROM:-}
PROFILE=
FROM_DIR=
WITH_ASSETS=0
SKIP_BOOTSTRAP=0
PACKAGE=1
PLATFORM=all
VARIANT=stock
OUTDIR=$REPO/dist

while [ $# -gt 0 ]; do
    case $1 in
        --variant) VARIANT=${2:?--variant needs stock or camera-controls}; shift 2 ;;
        --profile) PROFILE=${2:?--profile needs a value}; shift 2 ;;
        --profile=*) PROFILE=${1#*=}; shift ;;
        --from-dir) FROM_DIR=${2:?--from-dir needs a path}; shift 2 ;;
        --from-dir=*) FROM_DIR=${1#*=}; shift ;;
        --with-assets) WITH_ASSETS=1; shift ;;
        --skip-bootstrap) SKIP_BOOTSTRAP=1; shift ;;
        --no-package) PACKAGE=0; shift ;;
        --platform) PLATFORM=${2:?--platform needs all, windows or linux}; shift 2 ;;
        --platform=*) PLATFORM=${1#*=}; shift ;;
        --out) OUTDIR=${2:?--out needs a path}; shift 2 ;;
        --out=*) OUTDIR=${1#*=}; shift ;;
        -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
        -*) echo "unknown option: $1" >&2; exit 2 ;;
        *) ROM=$1; shift ;;
    esac
done

case "$VARIANT" in stock|camera-controls) ;; *) echo "Invalid variant: $VARIANT" >&2; exit 2 ;; esac

if [ "$VARIANT" = camera-controls ]; then export SOH_CAMERA_CONTROLS=1; else export SOH_CAMERA_CONTROLS=0; fi

log() { printf '\n==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

if [ -z "$FROM_DIR" ]; then
    if [ -z "$ROM" ]; then
        for candidate in "$REPO/rom/oot.z64" "$REPO/rom/rom.z64" "$REPO/rom/oot.n64" "$REPO/rom/oot.v64"; do
            if [ -f "$candidate" ]; then ROM=$candidate; break; fi
        done
    fi
    [ -n "$ROM" ] || die "no ROM found. Put your legally dumped Ocarina of Time ROM at rom/oot.z64, pass a path, or set \$SOH_ROM."
    ROM=$(cd -- "$(dirname -- "$ROM")" && pwd)/$(basename -- "$ROM")
    [ -f "$ROM" ] || die "ROM not found: $ROM"
    log "ROM: $ROM"
fi

if [ -z "$FROM_DIR" ] && [ "$SKIP_BOOTSTRAP" = 0 ]; then
    log "Checking prerequisites"
    missing=0
    for tool in git cmake ninja python3 patch clang-18 clang++-18 sha1sum; do
        command -v "$tool" >/dev/null 2>&1 || { echo "  missing: $tool"; missing=1; }
    done
    for dir in "$PS5_NATIVE_APP_TEMPLATE" "$PS5_OPENGL_ROOT" "$PS5_OPENGL_SDK"; do
        [ -d "$dir" ] || { echo "  missing SDK: $dir"; missing=1; }
    done
    [ "$missing" = 0 ] || die "prerequisites are missing; see docs/BUILDING.md sections 1-2."

    if [ ! -x "$PS5_NATIVE_APP_TEMPLATE/tooling/prospero-clang18++" ]; then
        log "Setting up the C++ toolchain wrapper"
        bash "$REPO/tools/setup-toolchain.sh"
    fi
    if [ ! -f "$DEPS_PREFIX/lib/libz.a" ]; then
        log "Building third-party dependencies"
        bash "$REPO/tools/build-deps.sh"
    fi
    if [ -z "$PROFILE" ] && [ ! -f "$PS5_SDL2_PREFIX/lib/libSDL2.a" ]; then
        log "Building SDL2 for PS5"
        bash "$REPO/tools/build-sdl2.sh"
    fi
    if [ ! -d "$SOH_SOURCE/.git" ]; then
        log "Fetching Ship of Harkinian 9.2.3"
        bash "$REPO/tools/fetch-soh.sh"
    fi
fi

if [ -n "$FROM_DIR" ]; then
    [ -d "$FROM_DIR" ] || die "no such directory: $FROM_DIR"
    DIST=$(cd -- "$FROM_DIR" && pwd)
    log "Packaging existing build: $DIST"
else
    if [ ! -s "$SOH_SOURCE/oot.o2r" ] || [ ! -s "$SOH_SOURCE/soh.o2r" ] ||
        ! cmp -s "$ROM" "$SOH_SOURCE/OTRExporter/oot.z64"; then
        log "Generating oot.o2r and soh.o2r from the ROM (host build)"
        bash "$REPO/tools/generate-assets.sh" "$ROM"
    else
        log "Reusing existing oot.o2r and soh.o2r"
    fi

    log "Building and packaging the title"
    if [ -n "$PROFILE" ]; then
        bash "$REPO/tools/build-profile.sh" "$PROFILE"
        DIST=$PS5SDK_ROOT/build/soh-$PROFILE/dist/$TITLE_ID
    else
        bash "$REPO/tools/build.sh"
        DIST=$PS5SDK_ROOT/build/soh-pkg/dist/$TITLE_ID
    fi
fi

log "Verifying the packaged title"
bash "$REPO/tools/check-build.sh" --dir "$DIST" --variant "$VARIANT"

actual_variant=$(python3 - "$DIST/build-profile.json" <<'PYCODE'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1])
print(json.loads(p.read_text()).get("controls_variant", "stock") if p.exists() else "stock")
PYCODE
)
[ "$actual_variant" = "$VARIANT" ] || die "build contains $actual_variant controls, requested $VARIANT"

if [ "$PACKAGE" = 0 ]; then
    log "Done: $DIST"
    exit 0
fi

version=$(git -C "$REPO" describe --tags --always --dirty 2>/dev/null || true)
[ -n "$version" ] || version=$(date -u +%Y%m%d)
profile=${PROFILE:-}
if [ -z "$profile" ] && [ -f "$DIST/build-profile.json" ]; then
    profile=$(python3 -c 'import json,sys; p=json.load(sys.stdin)["display_profile"]; print(str(p["height"])+"p"+str(p["fps"]))' \
        <"$DIST/build-profile.json" 2>/dev/null || true)
fi
[ -n "$profile" ] || profile=1080p60

platforms=${PLATFORM:-all}
case $platforms in
    all) platforms="windows linux" ;;
    windows | linux) ;;
    *) die "--platform must be all, windows or linux (got: $platforms)" ;;
esac
command -v python3 >/dev/null 2>&1 || die "python3 is required to package the release"

mkdir -p "$OUTDIR"
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT

log "Staging the release"
build=$stage/build
mkdir -p "$build/output" "$build/tools"
cp -a "$DIST" "$build/output/$TITLE_ID"
if [ "$WITH_ASSETS" = 0 ]; then
    rm -f "$build/output/$TITLE_ID/assets/oot.o2r"
fi
cp "$REPO/tools/install.ps1" "$REPO/tools/install.sh" \
    "$REPO/tools/make-assets.ps1" "$REPO/tools/make-assets.sh" \
    "$REPO/tools/index-mods.py" "$REPO/tools/configure-settings.py" "$build/tools/"
if [ -f "$REPO/docs/CONSOLE-SETUP.md" ]; then cp "$REPO/docs/CONSOLE-SETUP.md" "$build/"; fi

cp "$REPO/docs/SETTINGS.md" "$REPO/docs/MODS.md" "$build/"

write_install() {
    local file=$1 platform=$2
    {
        echo "Ship of Harkinian for PS5 ($TITLE_ID)"
        echo "profile: $profile"
        echo "version: $version"
        echo "controls: $VARIANT"
        if [ "$VARIANT" = camera-controls ]; then
            echo "Right stick: camera. D-pad: C buttons. X/O keep their normal bindings."
            echo "Uses the stock title ID; install one variant at a time."
        fi
        echo
        echo "Contents"
        echo "  output/$TITLE_ID/   the title; copy this one folder to the console"
        echo "  tools/               asset helper (and install helper on Windows)"
        echo "  CONSOLE-SETUP.md     console requirements and tested payloads"
        echo
        echo "What you need (no compiling)"
        echo "  - your own legally dumped Ocarina of Time ROM"
        echo "  - the official Ship of Harkinian 9.2.3 build for this platform (to create oot.o2r)"
        echo "  - a console with FTP (etaHEN) and folder-title support (kstuff + ShadowMountPlus);"
        echo "    see CONSOLE-SETUP.md"
        echo
        if [ "$WITH_ASSETS" = 0 ]; then
            echo "Quick start"
            echo "1. Create oot.o2r from your ROM; it is written to output/$TITLE_ID/assets/."
            if [ "$platform" = windows ]; then
                echo "     powershell -ExecutionPolicy Bypass -File tools\\make-assets.ps1 -Rom <oot.z64> -SoH <soh-windows folder>"
            else
                echo "     ./tools/make-assets.sh --rom <oot.z64> --soh <soh.appimage>"
            fi
        else
            echo "Quick start"
            echo "1. Game assets (oot.o2r, soh.o2r) are already included. Do not redistribute this"
            echo "   package: oot.o2r contains data derived from a ROM."
        fi
        echo
        echo "2. Copy output/$TITLE_ID to the console and register it"
        if [ "$platform" = windows ]; then
            echo "     powershell -ExecutionPolicy Bypass -File tools\\install.ps1 -Src .\\output\\$TITLE_ID -Console <console-ip>"
        else
            echo "     ./tools/install.sh --src output/$TITLE_ID --console <console-ip>"
        fi
        echo "   (or copy output/$TITLE_ID to /mnt/ext1/etaHEN/games/ yourself)"
        echo
        echo "3. Launch \"Ship of Harkinian\". See SETTINGS.md for menu, language and FPS setup."
        echo
        echo "For HD textures, read MODS.md; index-mods.py is included in tools/."
        echo "For language and the active config path, read SETTINGS.md."
        echo
        echo "The source repository and its docs/ folder have the full build guide."
    } >"$file"
}

made=0
for platform in $platforms; do
    base=soh-ps5-$profile-$version-$platform
    if [ "$VARIANT" = camera-controls ]; then base=soh-ps5-$profile-camera-controls-$version-$platform; fi
    if [ "$WITH_ASSETS" = 1 ]; then base=$base-with-assets; fi
    root=$stage/$base
    cp -a "$build" "$root"
    if [ "$platform" = windows ]; then
        rm -f "$root/tools/make-assets.sh" "$root/tools/install.sh"
    else
        rm -f "$root/tools/make-assets.ps1" "$root/tools/install.ps1"
    fi
    write_install "$root/INSTALL.txt" "$platform"
    archive=$OUTDIR/$base.zip
    rm -f "$archive" "$archive.sha256"
    log "Packaging $archive"
    python3 - "$root" "$archive" <<'PYZIP'
from pathlib import Path
import sys, zipfile
root, output = map(Path, sys.argv[1:])
with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    for path in sorted(root.rglob("*")):
        if path.is_file():
            archive.write(path, path.relative_to(root.parent))
PYZIP
    (cd "$OUTDIR" && sha256sum "$(basename -- "$archive")" | tee "$(basename -- "$archive").sha256")
    log "Release ready: $archive"
    made=1
done
[ "$made" = 1 ] || die "no platform selected"
