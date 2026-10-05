#!/usr/bin/env bash
# Check out Ship of Harkinian 9.2.3 with submodules and apply the PS5 patches.
set -euo pipefail
source "$(dirname "$0")/env.sh"
if [[ "${1:-}" == "--camera-controls" ]]; then
    shift
fi
if (( $# )); then
    echo "Usage: $0 [--camera-controls]" >&2
    exit 1
fi

if [ ! -d "$SOH_SOURCE/.git" ]; then
    git clone -q "$(lock "['shipwright']['url']")" "$SOH_SOURCE"
fi
cd "$SOH_SOURCE"
git -c advice.detachedHead=false checkout -q "$(lock "['shipwright']['revision']")"
git submodule update --init --recursive -q
git -C libultraship -c advice.detachedHead=false checkout -q "$(lock "['libultraship']['revision']")"

apply_patch() {
    if git -C "$1" apply --check "$2" 2>/dev/null; then git -C "$1" apply "$2";
    else git -C "$1" apply --reverse --check "$2"; fi
}
apply_patch "$SOH_SOURCE" "$REPO/patches/shipwright-ps5.patch"
apply_patch "$SOH_SOURCE/libultraship" "$REPO/patches/libultraship-ps5.patch"
echo "Ship of Harkinian ready at $SOH_SOURCE"
