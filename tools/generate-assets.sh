#!/usr/bin/env bash
# Generate oot.o2r and soh.o2r from your own Ocarina of Time ROM with a host (Linux) build of SoH.
# Usage: tools/generate-assets.sh /path/to/oot.z64
set -euo pipefail
source "$(dirname "$0")/env.sh"

rom=${1:?usage: generate-assets.sh /path/to/oot.z64}
host_build=$PS5SDK_ROOT/build/soh-host

destination=$SOH_SOURCE/OTRExporter/oot.z64
# The pinned rom_chooser.py searches ../OTRExporter/*.z64 from soh/.
if [ -e "$destination" ]; then
    cmp -s "$rom" "$destination" || { echo "A different ROM already exists at $destination" >&2; exit 1; }
else
    cp "$rom" "$destination"
fi
sha1sum "$destination"
cmake -S "$SOH_SOURCE" -B "$host_build" -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build "$host_build" --target ZAPD
cmake --build "$host_build" --target ExtractAssets
test -s "$SOH_SOURCE/oot.o2r" && test -s "$SOH_SOURCE/soh.o2r"
ls -la "$SOH_SOURCE"/*.o2r
