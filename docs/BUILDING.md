# Building

All steps run in Linux or WSL2 (Ubuntu 24.04). Paths default to `/opt/ps5sdk`; override
them with the variables in `tools/env.sh`.

## 1. Prerequisites

```sh
sudo apt install build-essential clang-18 lld-18 llvm-18 cmake ninja-build \
    python3 python3-venv git patch pkg-config
```

Place these under `$PS5SDK_ROOT` (default `/opt/ps5sdk`):

| Path | Contents |
| --- | --- |
| `native-app-boilerplate/` | ps5-native-app-boilerplate at the revision in `sources.lock.json`, with its native dependencies set up (`.deps/native/ps5-payload-sdk`, `runtime/libc.prx`) |
| `extracted/ps5-opengl-sdk-0.3.0/` | the extracted ps5-opengl SDK 0.3.0 release (1080p60) |
| `ps5-opengl-030/ps5-opengl/` | the ps5-opengl source bundled with that SDK (`sources/ps5-opengl.tar`) |

## 2. Toolchain and dependencies

Run the commands below from this repository root. Source the environment in the
current shell so later exports resolve `$PS5SDK_ROOT` correctly.

```sh
source tools/env.sh
tools/setup-toolchain.sh   # adds the prospero-clang18++ wrapper
tools/build-deps.sh        # zlib, libzip, json, tinyxml2, spdlog, ogg, vorbis, opus, opusfile
tools/build-sdl2.sh        # SDL2 for PS5 over ps5-opengl
```

### Patched graphics driver (recommended)

```sh
sudo apt install byacc bison flex python3-mako
python3 -m venv "$PS5SDK_ROOT/build-tools-venv"
source "$PS5SDK_ROOT/build-tools-venv/bin/activate"
python3 -m pip install "meson>=1.4" mako
tools/build-gl-driver.sh
export PS5_OPENGL_SDK=$PS5SDK_ROOT/gl-custom/sdk
```

This rebuilds the ps5-opengl runtime from the SDK's bundled sources with
`patches/ps5-opengl-perf.patch`, which cuts the driver's per-draw cost by about 4×:
- **Scanout flush:** stops flushing the whole scanout framebuffer from the CPU cache
  on every draw.
- **Depth clears:** fills depth with non-temporal stores, which skips a 10 MB cache flush.
- **Batch completion:** polls every 20 µs instead of sleeping 1 ms per check.
- **Descriptors:** partial copies and a bounded per-context cache reused after GPU retirement.
- **Streaming buffers:** constant-time checks for driver-owned buffer hazards; vertex
  cache flushes cover only the accessed range.
- **HD textures:** backing-keyed batch flush cache avoids redundant flushes after rebinding.
- **CPU work:** pooled command memory and `-O2` runtime compilation; successful batch
  logging is disabled unless profiling is enabled.

The first run builds Mesa, which takes about 15 minutes.

## 3. Source and game assets

The host extractor is configured through the desktop Linux project and needs its
development packages in addition to the PS5 cross-built libraries:

```sh
sudo apt install libsdl2-dev libglew-dev libgl1-mesa-dev zlib1g-dev libzip-dev \
    libtinyxml2-dev libspdlog-dev nlohmann-json3-dev libogg-dev libvorbis-dev \
    libopus-dev libopusfile-dev
```

```sh
tools/fetch-soh.sh                      # Shipwright 9.2.3 + libultraship, PS5 patches applied
tools/generate-assets.sh /path/to/oot.z64
```

`generate-assets.sh` builds SoH for the host and extracts `oot.o2r` and `soh.o2r` into the
Shipwright checkout. It keeps a local copy of the supplied ROM at
`OTRExporter/oot.z64`, where the pinned extractor searches for ROMs. Use a fresh
source tree for `fetch-soh.sh`; it checks out pins and applies patches once.

## 4. Build and package

```sh
tools/build.sh
```

This configures SoH with `ps5/cmake/ps5-soh.cmake` and patches the fetched ImGui backend.
It builds the executable's object/archive dependencies with `tools/compile-soh.py`
and links them into a native title with `tools/pack-soh.py`. Compilation errors stop
the build. CMake's own unsupported final executable link is skipped.

Output: `$PS5SDK_ROOT/build/soh-pkg/dist/PPSA99620`.

The packager recreates its output directory. Keep mod archives outside that
directory until packaging completes, then install them using [MODS.md](MODS.md).
Incremental builds and console runs have been validated; the complete dependency
bootstrap has not been re-run from an empty machine.

## 5. Install

From Windows (PowerShell), after copying the output folder to the PC:

```powershell
./tools/install.ps1 -Src .\PPSA99620 -Console <console-ip>
```

Use `-EbootOnly` to replace only the executable after a rebuild.

The helper expects FTP plus the local PS5Upload engine for stop/register/launch.
Use `-NoLaunch` for a manual launch workflow and stop the game yourself before
uploading. Consult [CONSOLE-SETUP.md](CONSOLE-SETUP.md) for the exact tested payloads
and their startup order. Preserve the title's existing config and saves when updating.

## Porting notes

- **Platform:** the title builds as a folder title against the native-app boilerplate. SoH is
  treated like the other console targets: no in-game extractor, and assets are shipped
  pre-generated in `/app0/assets`.
- **Data folder:** saves and configuration go to `/app0/UserData` when it is writable,
  otherwise `/download0`. The sandbox allows `stat`/`mkdir` but not directory listing.
  Mods use an explicit manifest (see [MODS.md](MODS.md)); preset scans are skipped.
- **libc gaps:** libc++ needs locale `*_l` functions, `__cxa_thread_atexit_impl` and a few
  POSIX calls that the native runtime does not export; `ps5/src/ps5_libc_shims.c` provides them.
- **Memory:** the app heap (2 GiB) is backed by direct memory; the default flexible memory
  budget is too small for SoH.
- **Rendering:**
  - The game renders into an RGBA8 framebuffer, which lets ps5-opengl batch its draws.
  - The frame is presented through ImGui with red and blue swapped, because the runtime's
    scanout format is BGRA.
  - Vertex data rotates through a pool of vertex buffers, so writes never stall on
    in-flight batches.
  - The window's depth buffer is never cleared, because only ImGui draws there.
  - PS5 interpolation uses monotonic deadlines. Rendering may drop expired subframes,
    but game/audio ticks are preserved. This prevents the previous proportional
    slow motion when a 60 FPS target cannot be met. It still requires at least one
    rendered frame plus game work to fit within a game tick.
