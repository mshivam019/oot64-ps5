# Ship of Harkinian for PS5

A native PS5 port of [Ship of Harkinian](https://github.com/HarbourMasters/Shipwright)
(The Legend of Zelda: Ocarina of Time PC port, version 9.2.3). It runs as a homebrew title
on jailbroken consoles and renders through the ps5-opengl SDK (OpenGL 3.3 Core over AGC).

The title installs as **Ship of Harkinian** (`PPSA99620`).

This repository contains only the PS5 port: patches, platform code and build scripts.
It contains **no game data**. You need your own legally dumped Ocarina of Time ROM.

## Status

- Boots to the title screen and is playable. Builds render at 1080p or natively at
  4K (`tools/build-profile.sh 2160p120`); the console scales the image to the TV.
- Targets 60 FPS interpolation with the patched graphics driver. Expired interpolated
  frames are skipped to preserve normal game speed under rendering load.
- Recent console samples averaged about 58–59 FPS with OoT Reloaded HD, both at 1080p
  and at 4K. These are sampled averages, not a locked-60 guarantee across the game.
- Draws are batched on the GPU.
- Saves and configuration are stored in the title's data folder.
- SDL audio works.
- HD texture archives load through an explicit manifest; optional PlayStation prompts
  match the default bindings (see [Mods](docs/MODS.md)).
- `p120` builds request 120 Hz only when the display reports support and otherwise keep
  60 Hz. 120 Hz output itself and full-game performance coverage remain unverified.

Tested on firmware 9.00 with standalone **kstuff + ShadowMountPlus** launched by
Payload Manager. See the exact tested versions in [Console setup](docs/CONSOLE-SETUP.md).

## Requirements

- Jailbroken PS5 with an FTP server and folder-title support through kstuff + ShadowMountPlus.
- About 200 MB of free space for the base game; about 4 GiB extra for OoT Reloaded HD.
- Your own Ocarina of Time ROM, converted into `oot.o2r` (see [Building](docs/BUILDING.md)).
- To build: Linux or WSL2 (Ubuntu 24.04), clang 18, CMake, Ninja, Python 3, the PS5 payload
  SDK, ps5-native-app-boilerplate and the ps5-opengl SDK 0.3.0.

## Installation

1. Build the title folder (see [docs/BUILDING.md](docs/BUILDING.md)), or use a release.
2. Make sure `PPSA99620/assets/` contains `oot.o2r` (from your ROM) and `soh.o2r`.
3. Copy the `PPSA99620` folder to the console, e.g. `/mnt/ext1/etaHEN/games/PPSA99620`.
4. Register the folder with your homebrew launcher and start **Ship of Harkinian** from
   the home screen.

`tools/install.ps1` automates steps 3–4 from Windows, using FTP and the PS5Upload engine.

With the patched driver, set **Interpolation FPS** to **60** in SoH's settings.
For HD textures and controller glyphs, follow [HD textures and PlayStation prompts](docs/MODS.md).

**120 FPS:** the current build outputs at 60 Hz. A 120 interpolation setting alone
does not change that. True 120 FPS would require a supported high-refresh output mode
and frames below 8.33 ms; current HD performance does not meet that budget.

## Layout

```
patches/        changes to Shipwright, libultraship and the ImGui OpenGL3 backend
ps5/src/        libc/locale shims the PS5 native runtime is missing
ps5/cmake/      CMake toolchain for the PS5 native app environment
ps5/art/        launcher icon and backgrounds
tools/          build, packaging and install scripts
docs/           build guide and porting notes
```

Title folder on the console:

```
PPSA99620/
├── eboot.bin
├── assets/       soh.o2r, oot.o2r, gamecontrollerdb.txt
├── sce_module/   runtime modules
├── sce_sys/      param.json, icon and backgrounds
└── UserData/     created at first launch
```

## Credits

- [Harbour Masters](https://github.com/HarbourMasters): Ship of Harkinian and
  [libultraship](https://github.com/kenix3/libultraship)
- [BlackBearReloaded](https://github.com/blackbearreloaded):
  [ps5-opengl](https://github.com/blackbearreloaded/ps5-opengl) and
  [ps5-native-app-boilerplate](https://github.com/blackbearreloaded/ps5-native-app-boilerplate)
- [ps5-payload-dev](https://github.com/ps5-payload-dev): PS5 payload SDK and the SDL2 port
- [Mesa](https://mesa3d.org), [Dear ImGui](https://github.com/ocornut/imgui)
- [Phi1ow/mkwii-ps5](https://github.com/Phi1ow/mkwii-ps5): reference for the title's data layout
- [GhostlyDark](https://github.com/GhostlyDark/OoT-Reloaded): optional OoT Reloaded textures
- [Kenney](https://kenney.nl/assets/input-prompts): CC0 controller prompt artwork

See [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).

Not affiliated with Nintendo or Sony. The Legend of Zelda is a trademark of Nintendo.
