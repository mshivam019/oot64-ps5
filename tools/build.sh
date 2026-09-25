#!/usr/bin/env bash
# Configure, compile and package Ship of Harkinian for PS5.
# Output: $PS5SDK_ROOT/build/soh-pkg/dist/PPSA99620
set -euo pipefail
source "$(dirname "$0")/env.sh"

cmake -S "$SOH_SOURCE" -B "$SOH_BUILD" -G Ninja -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
    -DCMAKE_BUILD_TYPE=Release -DBUILD_REMOTE_CONTROL=0

# ImGui is fetched by CMake; patch its OpenGL3 backend for the PS5 scanout format.
imgui=$SOH_BUILD/_deps/imgui-src
if ! grep -q "Out_Color.bgra" "$imgui/backends/imgui_impl_opengl3.cpp"; then
    patch -d "$imgui" -p1 < "$REPO/patches/imgui-ps5.patch"
fi

# Compile failures must stop packaging, even when stale objects exist.
python3 "$REPO/tools/compile-soh.py" "$SOH_BUILD"
python3 "$REPO/tools/pack-soh.py"
