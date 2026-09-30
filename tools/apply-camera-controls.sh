#!/usr/bin/env bash
# Optional right-stick camera + D-pad C buttons. Stock is the default.
set -euo pipefail
source "$(dirname "$0")/env.sh"
# Keep the selection made by fetch when no explicit build override is given.
# A freshly fetched source without --camera-controls is stock.
if [[ ! ${SOH_CAMERA_CONTROLS+x} ]]; then
    exit 0
fi
camera_controls=$SOH_CAMERA_CONTROLS
case "$camera_controls" in 0|1) ;; *) echo "SOH_CAMERA_CONTROLS must be 0 or 1" >&2; exit 1 ;; esac
camera_patch=$REPO/patches/shipwright-camera-controls.patch
if git -C "$SOH_SOURCE" apply --reverse --check "$camera_patch" >/dev/null 2>&1; then
    if [[ "$camera_controls" == 0 ]]; then
        git -C "$SOH_SOURCE" apply --reverse "$camera_patch"
        echo "Stock controller source selected"
    fi
elif [[ "$camera_controls" == 1 ]]; then
    git -C "$SOH_SOURCE" apply --check "$camera_patch"
    git -C "$SOH_SOURCE" apply "$camera_patch"
    echo "Right-stick camera controller source selected"
fi
