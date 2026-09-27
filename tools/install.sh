#!/usr/bin/env bash
# Upload the PPSA99620 title folder to the console over FTP.
# Register the folder from your usual homebrew launcher afterwards.
#
#   ./tools/install.sh --src output/PPSA99620 --console 192.168.1.50
set -euo pipefail

title=PPSA99620
src=
console=
ftpport=2121
install_root=/mnt/ext1/etaHEN/games

while [ $# -gt 0 ]; do
    case $1 in
        --src) src=${2:?--src needs a path}; shift 2 ;;
        --console) console=${2:?--console needs an address}; shift 2 ;;
        --ftp-port) ftpport=${2:?--ftp-port needs a value}; shift 2 ;;
        --install-root) install_root=${2:?--install-root needs a path}; shift 2 ;;
        -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
done

[ -n "$src" ] && [ -n "$console" ] || { echo "usage: install.sh --src <PPSA99620> --console <ip>" >&2; exit 2; }
[ -f "$src/eboot.bin" ] || { echo "eboot.bin not found in $src" >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "curl is required" >&2; exit 1; }

base="ftp://$console:$ftpport$install_root/$title"
# eboot.bin last, so a partial upload never leaves a new executable with old data.
while IFS= read -r file; do
    rel=${file#"$src"/}
    curl -s -S --ftp-create-dirs --connect-timeout 15 -u anonymous: -T "$file" "$base/$rel"
    echo "uploaded $rel"
done < <(find "$src" -type f ! -name eboot.bin | sort)
curl -s -S --ftp-create-dirs --connect-timeout 15 -u anonymous: -T "$src/eboot.bin" "$base/eboot.bin"
echo "uploaded eboot.bin"
echo "Now register $install_root/$title from your homebrew launcher."
