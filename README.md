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

Game assets used for recorded tests: **Ocarina of Time US/NTSC v1.2** → `oot.o2r`
(SoH 9.2.3). See [tested ROM details](docs/CONSOLE-SETUP.md#tested-game-assets)
for hashes and the language testing limits.

Tested on firmware 9.00 with standalone **kstuff + ShadowMountPlus** launched by
Payload Manager. See the exact tested versions in [Console setup](docs/CONSOLE-SETUP.md).

## Requirements

- Jailbroken PS5 with an FTP server and folder-title support through kstuff + ShadowMountPlus.
- About 200 MB of free space for the base game; about 4 GiB extra for OoT Reloaded HD.
- Your own Ocarina of Time ROM, converted into `oot.o2r` (see [Building](docs/BUILDING.md)).
- To build: Linux or WSL2 (Ubuntu 24.04), clang 18, CMake, Ninja, Python 3, the PS5 payload
  SDK, ps5-native-app-boilerplate and the ps5-opengl SDK 0.3.0.

## Installation

From a [release](https://github.com/mshivam019/oot64-ps5/releases), with no compiling:

[Release v1.2.0](https://github.com/mshivam019/oot64-ps5/releases/tag/v1.2.0) and new source builds enable **right-stick camera controls and HD textures / mods by default**, with independent switches in Settings → Mod Menu. Saved off settings are preserved. HD archives must be installed separately. See [SETTINGS.md](docs/SETTINGS.md).

Existing [stock v1.0.0](https://github.com/mshivam019/oot64-ps5/releases/tag/v1.0.0) and [camera-controls v1.1.0](https://github.com/mshivam019/oot64-ps5/releases/tag/v1.1.0) downloads predate these runtime toggles.

1. Download the archive for your PC (`-windows.zip`, or `-linux.zip` on Linux and
   macOS), extract it and open a terminal in the extracted folder.
2. Create `oot.o2r` from your own ROM with the official
   [Ship of Harkinian 9.2.3](https://github.com/HarbourMasters/Shipwright/releases) PC
   build and put it in `output/PPSA99620/assets/` (the archive already includes
   `soh.o2r`). The helper launches SoH once, waits for the extraction and copies the
   file; close the game when it starts.
3. Get the `output/PPSA99620` folder onto the console, e.g. at
   `/mnt/ext1/etaHEN/games/PPSA99620`, and register it with your homebrew launcher.
   Use whatever you already use (any FTP client such as FileZilla or WinSCP,
   PS5Upload, …); the `install` helpers below are optional.
4. Start **Ship of Harkinian** from the home screen.

**Windows** (PowerShell; `install.ps1` also registers and launches the title via PS5Upload):

```powershell
powershell -ExecutionPolicy Bypass -File tools\make-assets.ps1 -Rom <oot.z64> -SoH <soh-windows folder>
powershell -ExecutionPolicy Bypass -File tools\install.ps1 -Src .\output\PPSA99620 -Console <console-ip>
```

**Linux** (needs `curl`; register the folder from your homebrew launcher afterwards):

```sh
./tools/make-assets.sh --rom <oot.z64> --soh <soh.appimage>
./tools/install.sh --src output/PPSA99620 --console <console-ip>
```

**macOS:** use the Linux archive. Run the official `soh.app` once and select your ROM,
then copy `~/Library/Application Support/com.shipofharkinian.soh/oot.o2r` into
`output/PPSA99620/assets/`, then copy the folder over as in step 3 (or with
`./tools/install.sh`).

The archive's `INSTALL.txt` repeats these steps for its platform.

Building from source instead is covered in [docs/BUILDING.md](docs/BUILDING.md);
[docs/RELEASING.md](docs/RELEASING.md) packages a build for other people.

The updated PS5 source uses a fixed **60 FPS interpolation** target. Existing release
downloads still need **Interpolation FPS = 60** and **Match Refresh Rate off**.
See [Settings and language](docs/SETTINGS.md) for the separate port menu, active
config path and supported language requirements.
For HD textures and controller glyphs, follow [HD textures and PlayStation prompts](docs/MODS.md).

**120 Hz:** the release is the `2160p120` build. It asks for 120 Hz output when the
display reports support and otherwise stays at 60 Hz, so it is safe on 60 Hz TVs.
120 Hz output on a supporting display is untested, and 120 unique frames per second
would need frames below 8.33 ms; 4K with HD textures runs at about 58 FPS. Keep
Interpolation FPS at 60. See [Console setup](docs/CONSOLE-SETUP.md#display-and-frame-rate).

## Settings and language changes

New source builds scale the port menu for TV resolution and default to Large; adjust **Settings → General → Menu Size**.

The updated source adds **touchpad click** to open/close SoH's port settings menu.
Use the D-pad to navigate, Cross to select and Circle to go back. **Options** still
opens Zelda's pause/save screen. Settings → General also shows the active config
folder. The rebuilt SoH menu was checked on PS5: the user confirmed theme selection,
Mod Menu toggle access, Circle back and Triangle action-row access work. Builds
and executable checks passed; camera-toggle gameplay still needs confirmation.
Existing v1.0.0/v1.1.0 release downloads do not include the new shortcut.

To change game text, open **Settings → General → Language**:

- **English:** select English (`Languages = 0`). The recorded gameplay tests used
  **Ocarina of Time US/NTSC v1.2**, extracted with SoH 9.2.3.
- **German:** extract `oot.o2r` from your own supported European/PAL ROM using
  official SoH 9.2.3. Confirm German is available on PC, back up the PS5's old
  archive, close the title and replace `assets/oot.o2r`. Then select German
  (`Languages = 1`). German gameplay on this PS5 build remains unverified.
- **Spanish:** this version has no native Spanish language slot; a compatible
  translation mod would be needed.

The menu lists languages present in your assets. Changing the JSON cannot add
missing translations, and this setting changes game text rather than translating
all port-menu labels.

For existing downloads or manual configuration, close the game and edit its
**active** `shipofharkinian.json`. For writable folder titles it normally lives in
`PPSA99620/UserData/`; the fallback is the title's `/download0` sandbox. A file
beside `eboot.bin` is ignored. The correct nested setting is
**`CVars.gSettings.Languages`**, plural, with a numeric value. Preserve the rest
of the config and upload it to the same location.

See [Settings and config helper](docs/SETTINGS.md) for the full JSON example,
backup helper and sandbox details. The updated source fixes interpolation at
**60 FPS** and removes the adjustable FPS/refresh-match controls; actual frame
rate still depends on rendering load.

## HD texture setup

1. Download the **SoH O2R HD** pack described in [the HD texture guide](docs/MODS.md),
   and extract its `.o2r` archive.
2. Upload the archive to `PPSA99620/assets/mods/` together with **`mods.txt`** listing
   its exact filename. The guide includes a manual FileZilla example and an index
   helper. Copying only the compressed download or archive is insufficient.
3. Restart the title, then enable **Settings → Mod Menu → Enable Mods**, called
   **Enable HD textures / mods** in the updated source.

[The guide](docs/MODS.md) also covers stale manifests, mod priority and optional
PlayStation prompts. Preserve your game archives, configuration and saves when
updating.

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

- [Harbour Masters](https://github.com/HarbourMasters): Ship of Harkinian,
  [libultraship](https://github.com/kenix3/libultraship) and the Ship of Harkinian icon
  used for the launcher art
- [BlackBearReloaded](https://github.com/blackbearreloaded):
  [ps5-opengl](https://github.com/blackbearreloaded/ps5-opengl) and
  [ps5-native-app-boilerplate](https://github.com/blackbearreloaded/ps5-native-app-boilerplate)
- [ps5-payload-dev](https://github.com/ps5-payload-dev): PS5 payload SDK and the SDL2 port
- [Mesa](https://mesa3d.org), [Dear ImGui](https://github.com/ocornut/imgui)
- [Phi1ow/mkwii-ps5](https://github.com/Phi1ow/mkwii-ps5): reference for the title's data layout
- [GhostlyDark](https://github.com/GhostlyDark/OoT-Reloaded): optional OoT Reloaded textures
- [Kenney](https://kenney.nl/assets/input-prompts): CC0 controller prompt artwork

See [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).

## License

The port's own code, scripts and patches are licensed under the
[GNU General Public License v3.0 or later](LICENSE). The projects it builds on keep
their own licenses; see [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).

Not affiliated with Nintendo or Sony. The Legend of Zelda is a trademark of Nintendo.
