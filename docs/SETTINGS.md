# PS5 settings, language and HD textures

## Two different menus

**Options** is N64 Start: it opens Zelda's pause screen, including the game's save
prompt. Keep this binding. The desktop screenshot with a controller configuration
window shows SoH's separate port UI. This port is based on SoH 9.2.3, so its settings
layout differs from older screenshots.

In the updated PS5 build, **touchpad click** opens/closes the port menu and enables
controller navigation. Navigate with the D-pad, Cross to select and Circle to go
back. Game input is blocked while navigating the port menu. Close it with another
touchpad click to resume playing. **Options stays N64 Start/pause/save.**

F1 is the desktop SoH shortcut. This port's SDL bridge omits keyboard handling;
a USB keyboard is not an established menu-access method here. Existing release
downloads do not have the new touchpad shortcut. Until using the rebuilt
executable, edit the active JSON while the title is closed, as described below.
The updated source enables controller navigation on first launch; existing configs
that explicitly disabled it retain that preference until touchpad opens the menu.
The JSON setting for controller navigation is `CVars.gSettings.ControlNav = 1`.


## Language

Open **Settings → General → Language** in SoH's menu. This selects game text;
it does not translate every label in the port UI. Only languages whose message
tables are present in the extracted assets appear. A JSON setting cannot supply
missing text. Use the official SoH 9.2.3 PC extractor with your own supported ROM
containing the desired language, and replace the appropriate base game archive.
Keep your previous archive as a backup. Our recorded tests used the US/NTSC v1.2
ROM and English assets; German gameplay has not been verified. See the
[tested ROM](CONSOLE-SETUP.md#tested-game-assets).

The setting is **`Languages`**, plural. Values are English `0`, German `1`, French
`2`, Japanese `3`. Select only a language your assets support. Spanish is not a native language slot in this version. It requires a compatible
translation mod and is not included or validated in this update.

### English and German setup

- **English:** the tested US/NTSC v1.2 asset set works with `Languages = 0`.
- **German:** use your own supported European/PAL ROM. SoH 9.2.3 accepts PAL 1.0
  and PAL 1.1, among other PAL variants. Extract `oot.o2r` with the official PC
  build and first confirm that German appears in its Language menu. Back up the
  PS5's old `assets/oot.o2r`, close the PS5 title, upload the new archive, then
  choose German in SoH's port menu (`Languages = 1`). Keep UserData and saves.

ROM region and SoH version are separate: the tested ROM revision is US v1.2;
the extractor/port version is SoH 9.2.3. Selecting German in a JSON cannot convert
an English-only archive into the European asset set.

## Editing the correct JSON

1. In the updated build, **Settings → General** shows the active **Config folder**.
   Note it, close the game completely, then download and back up its existing config.
2. For a writable folder title installed on M.2, the normal path is:
   `/mnt/ext1/etaHEN/games/PPSA99620/UserData/shipofharkinian.json`.
   A file beside `eboot.bin` or under `assets/` is not the active config.
3. If the title cannot write to `UserData`, it uses its sandbox `/download0`
   instead. Use the title's sandbox/save-data access to find the generated file;
   a literal `/download0` FTP path is not guaranteed to expose that sandbox.
4. Merge settings into the existing JSON. Preserve controller settings, config
   version and other fields. Do not replace the entire file with this example:

   ```json
   {
     "CVars": {
       "gSettings": {
         "ControlNav": 1,
         "Languages": 1,
         "InterpolationFPS": 60,
         "MatchRefreshRate": 0,
         "AltAssets": 1
       }
     }
   }
   ```

5. Upload to the same active path and launch again. JSON requires numeric values
   here, not strings such as `"2"`; remove comments and trailing commas. Linux/PS5
   filenames are case-sensitive. Editing while the game runs can be overwritten.

The example selects German and alternate assets; change those only as needed.
If a setting is ignored, check the path, nesting and available language assets.

### Config helper (Windows, Linux and macOS)

With Python 3 installed, download the existing active config, close the game,
then run from the release folder:

```sh
python tools/configure-settings.py shipofharkinian.json --language german --hd-textures on
```

Use `python3` on Linux/macOS. Choose `--language english` for English. Omit
`--hd-textures` to preserve that setting. The helper backs up the original file,
preserves other fields, enables menu navigation and selects 60 FPS. Upload the
edited file to its original active location. It does not add German text or
install texture archives.

## Frame rate

The updated PS5 source has one **60 FPS interpolation** mode. Settings → Graphics
shows `Target frame rate: 60 FPS`; the adjustable FPS slider and Match Refresh Rate option
are removed for PS5. Old saved 20/30 FPS values no longer lower the target.
This change requires a rebuilt executable; existing v1.0.0/v1.1.0 downloads still
need `InterpolationFPS = 60` and `MatchRefreshRate = 0` set manually.

This is a rendering target, not a guarantee that every scene reaches 60 FPS. Game
logic retains its original timing. A 120 Hz display does not change this target.

## HD textures

Follow [MODS.md](MODS.md). The PS5 requires **both the extracted texture archive
and a `mods.txt` manifest**, then **Settings → Mod Menu → Enable Mods** (called **Enable HD textures / mods**
in the updated PS5 source) enabled. Merely copying
a ZIP, 7z or texture folder is insufficient.

## Menu size on a TV

PS5 source builds scale the port UI with output resolution (twice the native UI size at 4K), with Large as the default. Settings → General → Menu Size lets you choose Small, Normal, Large or X-Large. Existing size preferences remain saved. This changes the port menu, not game HUD or texture resolution.

To change a downloaded config before uploading it, add `--menu-size large` (or `x-large`) to `tools/configure-settings.py`. Close the title first.

Controller menu navigation: **L1/R1** change the top-level tab; **L2/R2** change its sidebar section. Use D-pad/left stick to focus controls, Cross to activate, and Circle to cancel a selector or popup. Custom tabs/sections show a focus outline. Shoulder shortcuts pause while a control is being edited or a popup is open. Touchpad closes the menu.
