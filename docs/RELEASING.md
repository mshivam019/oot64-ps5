# Releasing

Everything below runs on the same Linux/WSL2 machine you use to build. The ROM
stays local; only the packaged title folder (without game data) is distributed.

## What the person downloading a release does

A release archive is laid out so nobody needs Linux or a compiler:

```
soh-ps5-<profile>-<version>-windows/     (or -linux/)
├── output/
│   └── PPSA99620/  the title folder (contains soh.o2r, no oot.o2r)
├── SETTINGS.md, MODS.md  language/config and HD texture instructions
├── tools/          configure-settings.py, index-mods.py
│                   Windows: make-assets.ps1, install.ps1
│                   Linux:   make-assets.sh,  install.sh
├── INSTALL.txt
└── CONSOLE-SETUP.md
```

There is no macOS archive: macOS users take the Linux one and create `oot.o2r`
with the official macOS build (see its readme for where it writes the file).

`soh.o2r` is shipped because it is built with the port's `GenerateSohOtr` (`--norom`)
target and contains no ROM data. Only `oot.o2r` is ROM-derived, and the PC build of
Ship of Harkinian generates it:

1. Download the official Ship of Harkinian **9.2.3** Windows build and extract it.
2. `powershell -ExecutionPolicy Bypass -File tools\make-assets.ps1 -Rom <oot.z64> -SoH <soh-windows>`
   This copies the ROM next to `soh.exe`, launches the PC build once to extract
   `oot.o2r`, waits until the archive is complete and copies it into
   `output\PPSA99620\assets\`. Close the game once it starts.
   Linux: `./tools/make-assets.sh --rom <oot.z64> --soh <soh.appimage>`.
3. `powershell -ExecutionPolicy Bypass -File tools\install.ps1 -Src .\output\PPSA99620 -Console <console-ip>`
   Linux: `./tools/install.sh --src output/PPSA99620 --console <console-ip>`, then
   register the folder from your homebrew launcher.

The versions must match: the port is Shipwright 9.2.3, and every `.o2r` carries a
port version that the game checks.

## One command from your ROM (maintainer)

```sh
mkdir -p rom && cp /path/to/oot.z64 rom/oot.z64
tools/release.sh
```

`tools/release.sh`:

1. verifies the toolchain and SDKs, then bootstraps what is missing
   (`setup-toolchain.sh`, `build-deps.sh`, `build-sdl2.sh`, `fetch-soh.sh`);
2. generates `oot.o2r`/`soh.o2r` from your ROM with `generate-assets.sh`;
3. builds and packages the title with `build.sh`;
4. verifies the result with `check-build.sh`;
5. writes `dist/soh-ps5-<profile>-<version>-windows.zip` and `-linux.zip`, each
   with a `.sha256` next to it.

Useful flags:

| Flag | Effect |
| --- | --- |
| `--profile 2160p120` | matched GL/SDL build via `build-profile.sh` (also 1080p60, 1440p60, 2160p60, …) |
| `--from-dir DIR` | package an existing `PPSA99620` folder, skip the build |
| `--variant camera-controls` | default feature profile; camera can be disabled in the Mod Menu |
| `--with-assets` | include the ROM-derived `oot.o2r` (private use only; never distribute) |
| `--platform windows` | build only one archive (`windows` or `linux`; default both) |
| `--no-package` | stop after verification, leave the title folder in place |
| `--out DIR` | write archives somewhere other than `dist/` |
| `--skip-bootstrap` | assume dependencies and the source tree are ready |

The default build is the stock 1080p60 SDK and does not rebuild the graphics
driver. `--profile` selects a matched driver/SDL/title build and therefore runs
`build-gl-driver.sh` first (the first run builds Mesa and takes about 15 minutes).

## Build times

Measured on WSL2 (Ubuntu 24.04, 12 threads, 7 GB RAM) with the dependencies and
SDKs already installed. Expect the compile to scale with core count.

| Step | Time |
| --- | --- |
| `generate-assets.sh`, cold (host CMake configure ~70 s, ZAPD build, extraction) | ~3.5 min |
| `build.sh` (CMake configure ~70 s, compile, link, package) | ~27 min |
| `check-build.sh` + both zips | ~12 s |
| Full `tools/release.sh` (assets reused) | ~27 min |
| `build-gl-driver.sh`, first run (builds Mesa; `--profile` only) | ~15 min |
| `release.sh --from-dir` (validate + zips, no build) | < 1 min |
| `check-build.sh` / `check-build.sh --self-test` | < 2 s / ~15 s |

End-user steps, from an extracted release:

| Step | Time |
| --- | --- |
| Download the official SoH 9.2.3 Windows and Linux zips (95.5 MB) | ~10 s |
| `make-assets.ps1` (SoH extraction, including clicking its prompts) | ~3.5 min |
| `make-assets.sh` (AppImage extraction) | ~2 min |
| `install.ps1` / `install.sh` upload (~130 MB) | network bound; ~2 s on a local link |

## Checking a build

`tools/check-build.sh` validates any packaged `PPSA99620` folder and exits
non-zero if something is missing or wrong. Run it after a build, or point it at
any folder:

```sh
tools/check-build.sh                          # newest build under $PS5SDK_ROOT/build
tools/check-build.sh --dir /path/PPSA99620
tools/check-build.sh --update --dir /path/PPSA99620  # explicit executable/runtime update
tools/check-build.sh --json
tools/check-build.sh --self-test              # test the checker itself; no build needed
```

It checks that every required file exists and is the right size, and that the
headers and metadata are correct:

- `eboot.bin`, `sce_module/libc.prx`
- `assets/oot.o2r`, `assets/soh.o2r`, `assets/gamecontrollerdb.txt`
- `sce_sys/param.json`, `icon0.png`, `pic0.dds`, `pic1.dds`
- both `.o2r` archives open and pass a full integrity test (catches truncated copies)
- `param.json` `titleId`/`conceptId`/`contentId`/`titleName`
- the removed `sce_sys/snd0.at9` and stray `perf.txt` are absent

A release archive as shipped fails exactly one check, the missing `oot.o2r`; after
`make-assets.ps1`/`make-assets.sh` it passes. `--self-test` builds a synthetic
title folder, exercises the full-install, update and mod-manifest cases (missing, truncated or mislabelled files, wrong
IDs, invalid JSON, stray files) and confirms invalid folders and mismatched variants are rejected.

## Publishing to GitHub

Do not commit builds or game data. Upload a locally built archive with the
GitHub CLI:

```sh
git tag v1.0.0                                # archives are named after `git describe`
tools/release.sh --profile 2160p120           # published releases are the 4K build
tools/publish-release.sh v1.0.0 dist/soh-ps5-2160p120-v1.0.0-*.zip dist/*.sha256
```

Tag a clean, committed tree first; otherwise the archive names carry the commit
hash and a `-dirty` suffix (for example `soh-ps5-1080p60-841bd5c-dirty-windows.zip`).

On Windows use `tools/publish-release.ps1 v1.0.0 .\dist\soh-ps5-....zip .\dist\soh-ps5-....zip.sha256`
(or just `gh release create`). The GitHub CLI is a **publisher** requirement only:
the people who download and install the release need no GitHub CLI, Python or Linux.

`publish-release.sh` creates the release if needed (with an empty description) and
uploads the archive and its checksum. Only attach archives built **without**
`--with-assets`.

There is no CI build job: a clean build needs the PS5 SDK, a Mesa toolchain and
your ROM, which GitHub-hosted runners cannot provide. A workflow would only make
sense on a self-hosted runner.

## Camera controls variant

Camera support is included in the main PS5 patch and every normal build. Package with the default `--variant camera-controls`; users can turn it off in the Mod Menu. HD textures / mods also default to enabled, while existing saved off preferences persist. `--variant stock` only describes legacy executables packaged from an existing folder; it does not select a new stock source build.

`PS5_COMPILER_RT` can select an existing `libclang_rt.builtins-x86_64.a` when
clang 18 is installed outside the normal executable path.

Use `tools/check-build.sh --dir /path/PPSA99620 --variant camera-controls`
to require the camera build. Its profile records the controls variant and the
executable SHA-256; validation rejects a mismatch. Legacy stock builds remain
supported with `--variant stock`. Release packaging runs this check automatically.

The `--update` mode requires the executable, matching libc runtime, a recorded
executable SHA-256, and `game_assets_included=false`. It does not establish a
complete installation: existing assets and title metadata must be retained.
Normal mode still rejects missing base archives. Both modes validate optional
mod manifests, archive paths, duplicate names and archive integrity when mods
are present. The writable UserData manifest takes precedence over bundled mods.
