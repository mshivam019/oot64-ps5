#!/usr/bin/env bash
# Check out Ship of Harkinian 9.2.3 with submodules and apply the PS5 patches.
set -euo pipefail
source "$(dirname "$0")/env.sh"
if [[ "${1:-}" == "--camera-controls" ]]; then
    export SOH_CAMERA_CONTROLS=1
    shift
fi
if (( $# )); then
    echo "Usage: $0 [--camera-controls] (or SOH_CAMERA_CONTROLS=1)" >&2
    exit 1
fi

if [ ! -d "$SOH_SOURCE/.git" ]; then
    git clone -q "$(lock "['shipwright']['url']")" "$SOH_SOURCE"
fi
cd "$SOH_SOURCE"
git -c advice.detachedHead=false checkout -q "$(lock "['shipwright']['revision']")"
git submodule update --init --recursive -q
git -C libultraship -c advice.detachedHead=false checkout -q "$(lock "['libultraship']['revision']")"

git apply --check "$REPO/patches/shipwright-ps5.patch"
git apply "$REPO/patches/shipwright-ps5.patch"
git -C libultraship apply --check "$REPO/patches/libultraship-ps5.patch"
git -C libultraship apply "$REPO/patches/libultraship-ps5.patch"
bash "$REPO/tools/apply-camera-controls.sh"
echo "Ship of Harkinian ready at $SOH_SOURCE"
