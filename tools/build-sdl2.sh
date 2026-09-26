#!/usr/bin/env bash
# Build the PS5 SDL2 port against the ps5-opengl SDK using the SDK's own integration script.
set -euo pipefail
source "$(dirname "$0")/env.sh"

sdl=$PS5SDK_ROOT/src/SDL
revision=$(lock "['sdl2']['revision']")
[ -d "$sdl" ] || git clone -q "$(lock "['sdl2']['url']")" "$sdl"
git -C "$sdl" fetch -q origin "$revision" || true
git -C "$sdl" -c advice.detachedHead=false checkout -q "$revision"

cd "$PS5_OPENGL_ROOT"
# The SDK's integration disables SDL audio; enable the PS5 (sceAudioOut) backend.
if ! grep -q "SceAudioOut" integration/SDL2/CMakeLists.txt; then
    patch -p1 < "$REPO/patches/ps5-opengl-sdl2-audio.patch"
fi
# Report the refresh rate the runtime actually negotiated, not the build profile's.
if ! grep -q "sync_refresh_rate" integration/SDL2/SDL_ps5g19.c; then
    patch -p1 < "$REPO/patches/ps5-opengl-sdl2-refresh.patch"
fi
out=${PS5_SDL2_BUILD:-$PS5_OPENGL_ROOT/build/sdl2-native}
rm -rf "$out"
python3 integration/SDL2/build.py native --sdl-source "$sdl" --sdk-prefix "$PS5_OPENGL_SDK" \
    --out "$out" --payload-sdk "$PS5_PAYLOAD_SDK" \
    --compiler-wrapper "$PS5_NATIVE_APP_TEMPLATE/tooling/prospero-clang18"
ls "$out/sdk/lib/libSDL2.a"
