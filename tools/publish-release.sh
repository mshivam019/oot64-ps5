#!/usr/bin/env bash
# Create a GitHub Release and upload locally built packages.
#
# Game data stays off GitHub: build with tools/release.sh (no --with-assets) and
# upload the resulting archive here. Requires the GitHub CLI (gh) logged in.
#
#   tools/publish-release.sh v1.0.0 dist/soh-ps5-2160p120-v1.0.0-windows.zip
#   tools/publish-release.sh v1.0.0 dist/*.zip dist/*.sha256
set -euo pipefail

REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tag=${1:?usage: publish-release.sh <tag> <archive...>}
shift
[ $# -gt 0 ] || { echo "usage: publish-release.sh <tag> <archive...>" >&2; exit 2; }
command -v gh >/dev/null 2>&1 || { echo "GitHub CLI (gh) is required: https://cli.github.com" >&2; exit 1; }
for file in "$@"; do
    [ -f "$file" ] || { echo "no such file: $file" >&2; exit 1; }
done

cd "$REPO"
if gh release view "$tag" >/dev/null 2>&1; then
    echo "Uploading to existing release $tag"
    gh release upload "$tag" "$@" --clobber
else
    echo "Creating release $tag"
    gh release create "$tag" "$@" --title "$tag" --notes ""
fi
gh release view "$tag" --json url --jq .url
