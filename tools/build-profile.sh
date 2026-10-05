#!/usr/bin/env bash
# Build a matched GL/SDL title without changing the previously tested SDK/build.
set -euo pipefail
source "$(dirname "$0")/env.sh"
profile=${1:-1080p60}
case "$profile" in
    4k60) profile=2160p60 ;;
    4k120) profile=2160p120 ;;
esac
case "$profile" in
    1080p60|1080p120|1440p60|1440p120|2160p60|2160p120) ;;
    *) echo "Usage: $0 [1080p60|1440p60|2160p60|...p120|4k60|4k120]" >&2
       echo "p120 profiles use 120 Hz only when the display accepts it, else 60 Hz" >&2; exit 1 ;;
esac
height=${profile%%p*} fps=${profile##*p}

# Input is always the original release SDK, not an SDK mutated by a prior profile.
export PS5_OPENGL_SDK=$PS5SDK_ROOT/extracted/ps5-opengl-sdk-0.3.0/sdk
export PS5_OPENGL_OUTPUT_SDK=$PS5SDK_ROOT/gl-$profile/sdk
export PS5_SCANOUT_HEIGHT=$height PS5_SCANOUT_FPS=$fps
bash "$REPO/tools/build-gl-driver.sh"
export PS5_OPENGL_SDK=$PS5_OPENGL_OUTPUT_SDK
export PS5_SDL2_BUILD=$PS5_OPENGL_ROOT/build/soh-sdl-$profile
bash "$REPO/tools/build-sdl2.sh"
export PS5_SDL2_PREFIX=$PS5_SDL2_BUILD/sdk

# Game calls SDL for the fixed window dimensions; it does not bake in this profile.
# Compile its objects once, then package with the selected SDL and GL libraries.
python3 "$REPO/tools/compile-soh.py" "$SOH_BUILD"
python3 "$REPO/tools/pack-soh.py" --out "$PS5SDK_ROOT/build/soh-$profile"
