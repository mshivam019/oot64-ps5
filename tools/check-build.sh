#!/usr/bin/env bash
# Check a packaged Ship of Harkinian title folder (PPSA99620) for completeness.
#
# Run this after tools/build.sh or tools/build-profile.sh if a build looks wrong,
# or before copying a build to the console. Exits non-zero on any problem.
#
# Usage:
#   tools/check-build.sh                      # newest build under $PS5SDK_ROOT/build
#   tools/check-build.sh --dir /path/PPSA99620
#   tools/check-build.sh --variant camera-controls --dir /path/to/PPSA99620
#   tools/check-build.sh --json               # machine-readable summary
#   tools/check-build.sh --self-test          # check the checker on synthetic folders
set -uo pipefail

REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=/dev/null
source "$REPO/tools/env.sh" 2>/dev/null || true
PS5SDK_ROOT=${PS5SDK_ROOT:-/opt/ps5sdk}

TITLE_ID=PPSA99620
CONCEPT_ID=99620
CONTENT_ID=UP9000-PPSA99620_00-SHIPOFHARKINIAN0

DIR=
JSON=0
VARIANT=
while [ $# -gt 0 ]; do
    case $1 in
        --dir) DIR=${2:?--dir needs a path}; shift 2 ;;
        --dir=*) DIR=${1#*=}; shift ;;
        --json) JSON=1; shift ;;
        --variant) VARIANT=${2:?--variant needs stock or camera-controls}; shift 2 ;;
        --self-test) SELF_TEST=1; shift ;;
        -h|--help) sed -n '2,11p' "$0"; exit 0 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done

case "$VARIANT" in ""|stock|camera-controls) ;; *) echo "Invalid controls variant: $VARIANT" >&2; exit 2 ;; esac

# Build a synthetic title folder that passes, then break it one way at a time and
# confirm each break is caught. Needs no SDK, build or game data.
self_test() {
    local work self=${BASH_SOURCE[0]} passed=0 failed=0
    work=$(mktemp -d)
    trap 'rm -rf "$work"' RETURN

    make_fixture() {
        local d=$1
        mkdir -p "$d/sce_module" "$d/sce_sys" "$d/assets"
        pad() { { printf "$2"; head -c "$3" /dev/zero; } >"$d/$1"; }
        pad eboot.bin '\x4f\x15\x3d\x1d' 1100000
        pad sce_module/libc.prx '\x54\x14\xf5\xee' 110000
        pad sce_sys/icon0.png '\x89PNG\r\n\x1a\n' 2048
        pad sce_sys/pic0.dds 'DDS ' 2048
        pad sce_sys/pic1.dds 'DDS ' 2048
        head -c 2048 /dev/zero | tr '\0' '#' >"$d/assets/gamecontrollerdb.txt"
        python3 - "$d" "$TITLE_ID" "$CONCEPT_ID" "$CONTENT_ID" <<'PY'
import json, os, sys, zipfile
d, title, concept, content = sys.argv[1:5]
for name, size in (("oot.o2r", 1_200_000), ("soh.o2r", 150_000)):
    with zipfile.ZipFile(os.path.join(d, "assets", name), "w", zipfile.ZIP_STORED) as z:
        z.writestr("blob", os.urandom(size))
json.dump({"titleId": title, "conceptId": concept, "contentId": content,
           "localizedParameters": {"defaultLanguage": "en-US",
                                   "en-US": {"titleName": "Ship of Harkinian"}},
           "padding": "x" * 64},
          open(os.path.join(d, "sce_sys", "param.json"), "w"))
PY
    }

    expect() {
        local want=$1 name=$2 dir=$3 rc
        shift 3
        bash "$self" --dir "$dir" "$@" >"$work/out" 2>&1
        rc=$?
        if [ "$rc" = "$want" ]; then
            echo "  ok    $name"
            passed=$((passed + 1))
        else
            echo "  FAIL  $name (exit $rc, expected $want)"
            sed 's/^/        /' "$work/out"
            failed=$((failed + 1))
        fi
    }

    case_dir() { rm -rf "$work/case"; cp -a "$work/good" "$work/case"; echo "$work/case"; }

    make_fixture "$work/good"
    echo "Self-test"
    expect 0 "valid folder passes" "$work/good"
    local c
    c=$(case_dir); rm "$c/eboot.bin"; expect 1 "missing eboot.bin" "$c"
    c=$(case_dir); rm "$c/assets/oot.o2r"; expect 1 "missing oot.o2r" "$c"
    c=$(case_dir); rm "$c/assets/soh.o2r"; expect 1 "missing soh.o2r" "$c"
    c=$(case_dir); head -c 1 "$work/good/eboot.bin" >"$c/eboot.bin"; expect 1 "1-byte eboot.bin" "$c"
    c=$(case_dir); printf 'XXXX' | dd of="$c/eboot.bin" conv=notrunc 2>/dev/null; expect 1 "wrong eboot.bin magic" "$c"
    c=$(case_dir); head -c 1100000 "$work/good/assets/oot.o2r" >"$c/assets/oot.o2r"; expect 1 "truncated oot.o2r" "$c"
    c=$(case_dir); sed -i 's/"PPSA99620"/"PPSA00000"/' "$c/sce_sys/param.json"; expect 1 "wrong titleId" "$c"
    c=$(case_dir); echo '{' >"$c/sce_sys/param.json"; head -c 200 /dev/zero | tr '\0' ' ' >>"$c/sce_sys/param.json"
    expect 1 "invalid param.json" "$c"
    c=$(case_dir); touch "$c/perf.txt"; expect 1 "stray perf.txt" "$c"
    c=$(case_dir); : >"$c/sce_sys/snd0.at9"; expect 1 "stray snd0.at9" "$c"
    c=$(case_dir); echo '{' >"$c/build-profile.json"; expect 1 "invalid build-profile.json" "$c"
    c=$(case_dir); echo '{}' >"$c/build-profile.json"; expect 0 "valid build-profile.json" "$c"
    c=$(case_dir); echo '{"controls_variant":"unknown"}' >"$c/build-profile.json"
    expect 1 "unknown controls variant" "$c"
    expect 0 "legacy stock variant accepted" "$work/good" --variant stock
    expect 1 "stock cannot be labeled camera" "$work/good" --variant camera-controls
    c=$(case_dir)
    python3 - "$c" <<'PYFIXTURE'
import hashlib, json, pathlib, sys
p = pathlib.Path(sys.argv[1])
(p / "build-profile.json").write_text(json.dumps({"controls_variant": "camera-controls",
    "executable_sha256": hashlib.sha256((p / "eboot.bin").read_bytes()).hexdigest()}))
PYFIXTURE
    expect 0 "camera variant and executable match" "$c" --variant camera-controls
    expect 1 "camera cannot be labeled stock" "$c" --variant stock
    printf X >>"$c/eboot.bin"
    expect 1 "mismatched executable rejected" "$c" --variant camera-controls
    echo '{"controls_variant":"camera-controls"}' >"$c/build-profile.json"
    expect 1 "camera profile requires executable hash" "$c"
    expect 1 "nonexistent directory" "$work/missing"

    echo
    if [ "$failed" = 0 ]; then
        echo "SELF-TEST PASS: $passed case(s)"
        return 0
    fi
    echo "SELF-TEST FAIL: $failed of $((passed + failed)) case(s)"
    return 1
}

if [ "${SELF_TEST:-0}" = 1 ]; then
    self_test
    exit $?
fi

FAIL=()
WARN=()
OK=()

human() { numfmt --to=iec --suffix=B "$1" 2>/dev/null || echo "$1"; }
magic() { head -c "$2" "$1" 2>/dev/null | od -An -tx1 | tr -d ' \n'; }
json_escape() { python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1"; }

find_default() {
    local found
    found=$(find "$PS5SDK_ROOT/build" -maxdepth 3 -type d -name "$TITLE_ID" -printf '%T@ %p\n' 2>/dev/null |
        sort -rn | head -1 | cut -d' ' -f2-)
    if [ -n "$found" ]; then printf '%s\n' "$found"; return 0; fi
    if [ -d "$REPO/dist/$TITLE_ID" ]; then printf '%s\n' "$REPO/dist/$TITLE_ID"; return 0; fi
    return 1
}

if [ -z "$DIR" ]; then
    if ! DIR=$(find_default); then
        echo "No $TITLE_ID folder found under $PS5SDK_ROOT/build or $REPO/dist." >&2
        echo "Build it first (tools/build.sh), or pass --dir /path/to/$TITLE_ID." >&2
        exit 1
    fi
fi
if [ ! -d "$DIR" ]; then
    echo "no such directory: $DIR" >&2
    exit 1
fi
DIR=$(cd -- "$DIR" && pwd)

check_file() {
    local rel=$1 min=$2 want=${3:-} label=${4:-$1} size got
    local p=$DIR/$rel
    if [ ! -e "$p" ]; then FAIL+=("missing file: $label"); return; fi
    if [ ! -f "$p" ]; then FAIL+=("not a regular file: $label"); return; fi
    size=$(stat -c%s "$p" 2>/dev/null || echo 0)
    if [ "$size" -lt "$min" ]; then
        FAIL+=("incomplete file: $label is $size bytes, expected at least $min")
        return
    fi
    if [ -n "$want" ]; then
        got=$(magic "$p" "$((${#want} / 2))")
        if [ "$got" != "$want" ]; then
            FAIL+=("corrupt file: $label header is ${got:-empty}, expected $want")
            return
        fi
    fi
    OK+=("$label ($(human "$size"))")
}

check_absent() {
    if [ -e "$DIR/$1" ]; then
        FAIL+=("unexpected file present: $1")
    else
        OK+=("$1 absent (expected)")
    fi
}

check_zip() {
    local rel=$1 label=${2:-$1} out rc
    # A missing file is already reported by check_file.
    [ -f "$DIR/$rel" ] || return
    out=$(python3 - "$DIR/$rel" <<'PY'
import sys, zipfile
try:
    bad = zipfile.ZipFile(sys.argv[1]).testzip()
except Exception as e:
    print(e)
    raise SystemExit(1)
if bad is not None:
    print(f"corrupt entry: {bad}")
    raise SystemExit(1)
PY
    )
    rc=$?
    if [ $rc -eq 0 ]; then
        OK+=("$label archive integrity")
    else
        FAIL+=("$label archive failed integrity: $out")
    fi
}

check_param() {
    local out rc
    out=$(python3 - "$DIR/sce_sys/param.json" "$TITLE_ID" "$CONCEPT_ID" "$CONTENT_ID" 2>&1 <<'PY'
import json, sys
path, title, concept, content = sys.argv[1:5]
try:
    p = json.load(open(path, encoding="utf-8"))
except Exception as e:
    print(f"sce_sys/param.json is not valid JSON: {e}")
    raise SystemExit(1)
errors = []
if p.get("titleId") != title:
    errors.append(f"sce_sys/param.json titleId={p.get('titleId')!r}, expected {title!r}")
if p.get("conceptId") != concept:
    errors.append(f"sce_sys/param.json conceptId={p.get('conceptId')!r}, expected {concept!r}")
if p.get("contentId") != content:
    errors.append(f"sce_sys/param.json contentId={p.get('contentId')!r}, expected {content!r}")
localized = p.get("localizedParameters") or {}
language = localized.get("defaultLanguage")
name = (localized.get(language) or {}).get("titleName")
if not name:
    errors.append("sce_sys/param.json has no titleName for its default language")
for e in errors:
    print(e)
raise SystemExit(1 if errors else 0)
PY
    )
    rc=$?
    if [ $rc -eq 0 ]; then
        OK+=("sce_sys/param.json metadata")
    else
        while IFS= read -r line; do
            [ -n "$line" ] && FAIL+=("$line")
        done <<<"$out"
    fi
}

check_file eboot.bin 1000000 4f153d1d "eboot.bin"
check_file sce_module/libc.prx 100000 5414f5ee "sce_module/libc.prx"
check_file assets/oot.o2r 1000000 504b0304 "assets/oot.o2r (release packages ship without it)"
check_file assets/soh.o2r 100000 504b0304 "assets/soh.o2r"
check_file assets/gamecontrollerdb.txt 1024 "" "assets/gamecontrollerdb.txt"
check_file sce_sys/param.json 100 "" "sce_sys/param.json"
check_file sce_sys/icon0.png 1024 89504e470d0a1a0a "sce_sys/icon0.png"
check_file sce_sys/pic0.dds 1024 44445320 "sce_sys/pic0.dds"
check_file sce_sys/pic1.dds 1024 44445320 "sce_sys/pic1.dds"
check_absent sce_sys/snd0.at9
check_absent perf.txt
check_zip assets/oot.o2r
check_zip assets/soh.o2r
check_param

profile_result=$(python3 - "$DIR" "$VARIANT" <<'PYPROFILE'
import hashlib, json, pathlib, sys
root = pathlib.Path(sys.argv[1])
expected = sys.argv[2]
try:
    path = root / "build-profile.json"
    profile = json.loads(path.read_text()) if path.exists() else {}
    if not isinstance(profile, dict):
        raise ValueError("build-profile.json must be an object")
    variant = profile.get("controls_variant", "stock")
    if variant not in ("stock", "camera-controls"):
        raise ValueError(f"unknown controls variant: {variant!r}")
    if expected and variant != expected:
        raise ValueError(f"controls variant is {variant}, expected {expected}")
    digest = profile.get("executable_sha256")
    if variant == "camera-controls" and not digest:
        raise ValueError("camera-controls profile is missing executable_sha256")
    if digest and digest != hashlib.sha256((root / "eboot.bin").read_bytes()).hexdigest():
        raise ValueError("build-profile.json executable SHA-256 does not match eboot.bin")
    print(f"controls variant: {variant}" + ("; executable SHA-256 verified" if digest else " (legacy profile)"))
except (ValueError, OSError) as error:
    print(error)
    sys.exit(1)
PYPROFILE
)
if [ $? -eq 0 ]; then
    OK+=("$profile_result")
else
    FAIL+=("$profile_result")
fi
if [ ! -f "$DIR/build-profile.json" ]; then
    WARN+=("no build-profile.json (stock 0.3.0 driver profile)")
fi

if [ "$JSON" = 1 ]; then
    printf '{"dir": %s, "ok": [' "$(json_escape "$DIR")"
    sep=
    for x in "${OK[@]}"; do printf '%s%s' "$sep" "$(json_escape "$x")"; sep=,; done
    printf '], "warnings": ['
    sep=
    for x in "${WARN[@]}"; do printf '%s%s' "$sep" "$(json_escape "$x")"; sep=,; done
    printf '], "failures": ['
    sep=
    for x in "${FAIL[@]}"; do printf '%s%s' "$sep" "$(json_escape "$x")"; sep=,; done
    printf ']}\n'
else
    echo "Checking: $DIR"
    for x in "${OK[@]}"; do echo "  OK    $x"; done
    for x in "${WARN[@]}"; do echo "  WARN  $x"; done
    for x in "${FAIL[@]}"; do echo "  FAIL  $x"; done
    echo
fi

if [ ${#FAIL[@]} -eq 0 ]; then
    echo "PASS: ${#OK[@]} checks passed, ${#WARN[@]} warning(s)"
    exit 0
fi
echo "FAIL: ${#FAIL[@]} problem(s) found in $DIR"
exit 1
