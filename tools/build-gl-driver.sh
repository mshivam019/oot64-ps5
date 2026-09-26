#!/usr/bin/env bash
# Rebuild the SDK 0.3.0 runtime with the SoH patches and a matched display profile.
# Output SDK: $PS5SDK_ROOT/gl-<height>p<fps>/sdk (use it with: export PS5_OPENGL_SDK=...)
#
# Needs: meson >= 1.4, byacc, bison, flex, python3-mako, network access for the pinned
# opengnm / SPIRV-Headers / Vulkan-Headers checkouts.
set -euo pipefail
source "$(dirname "$0")/env.sh"

src=$PS5_OPENGL_ROOT
bundle=$(dirname "$PS5_OPENGL_SDK")/sources
height=${PS5_SCANOUT_HEIGHT:-1080}
fps=${PS5_SCANOUT_FPS:-60}
case "$height" in 1080|1440|2160) ;; *) echo "Unsupported scanout height: $height" >&2; exit 1 ;; esac
# 120 means "use 120 Hz if the display accepts it"; the runtime otherwise keeps 60 Hz.
case "$fps" in 60|120) ;; *) echo "Unsupported refresh rate: $fps (use 60 or 120)" >&2; exit 1 ;; esac
profile=${height}p${fps}
out=${PS5_OPENGL_OUTPUT_SDK:-$PS5SDK_ROOT/gl-$profile/sdk}
runtime_build=$src/build/soh-runtime-$profile
pin() { python3 -c "import json; print(json.load(open('$src/dependencies.json'))$1)"; }

cd "$src/third_party"
[ -f mesa-26.2.0/VERSION ] || tar xf "$bundle/mesa-26.2.0.tar.xz"
[ -f mesa-26.2.0.tar.xz ] || cp "$bundle/mesa-26.2.0.tar.xz" .

# opengnm-psbc ships as a plain tarball; the build verifies the patched git tree hash.
if [ ! -d opengnm-psbc/.git ]; then
    rm -rf opengnm-psbc && tar xf "$bundle/opengnm-psbc.tar"
    git -C opengnm-psbc init -q
    git -C opengnm-psbc apply "$src/toolchain/opengnm-psbc-ps5.patch"
    git -C opengnm-psbc add -A
fi
# The build also checks these three by commit, so they must be real checkouts.
for dep in opengnm SPIRV-Headers Vulkan-Headers; do
    revision=$(pin "['repositories']['$dep']['revision']")
    if [ "$(git -C "$dep" rev-parse HEAD 2>/dev/null)" != "$revision" ]; then
        rm -rf "$dep" && mkdir "$dep"
        git -C "$dep" init -q
        git -C "$dep" fetch -q --depth=1 "$(pin "['repositories']['$dep']['url']")" "$revision"
        git -C "$dep" -c advice.detachedHead=false checkout -q FETCH_HEAD
    fi
done

cd "$src"
if patch --dry-run --forward --batch -p1 < "$REPO/patches/ps5-opengl-perf.patch" >/dev/null 2>&1; then
    patch --forward --batch -p1 < "$REPO/patches/ps5-opengl-perf.patch"
elif ! patch --dry-run --reverse --batch -p1 < "$REPO/patches/ps5-opengl-perf.patch" >/dev/null 2>&1; then
    echo "Driver sources do not match the current patch; use clean SDK 0.3.0 sources." >&2
    exit 1
fi
if [ ! -f build/mesa-ps5-probe/src/mesa/libmesa.a ]; then
    bash toolchain/build-opengnm-psbc.sh
    bash toolchain/build-opengnm-psbc-ps5.sh
    PS5_MESA_CROSS_FILE="$PS5_PAYLOAD_SDK/toolchain/prospero.ini" bash toolchain/build-mesa-ps5.sh
fi
make -s -C tests/ps5 -f native-app.mk runtime PS5_OPENGL_BUILD="$runtime_build" PS5_SCANOUT_FPS="$fps" PS5_SCANOUT_HEIGHT="$height" PS5_GPU_PRESENT_BATCH=1 PS5_DEFERRED_DRAW_BATCH=1

# Keep the SDK's regular Mesa archives; replace the runtime and record provenance.
if [ "$(realpath -m "$PS5_OPENGL_SDK")" != "$(realpath -m "$out")" ]; then
    rm -rf "$out"
    mkdir -p "$(dirname "$out")"
    cp -r "$PS5_OPENGL_SDK" "$out"
fi
cp "$runtime_build/libps5_opengl_core33.a" "$out/lib/"
python3 "$REPO/tools/record-gl-profile.py" "$out" "$runtime_build/runtime-config.txt" "$height" "$fps"
echo "patched SDK ready: export PS5_OPENGL_SDK=$out"
