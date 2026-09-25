# HD textures and PlayStation prompts

The PS5 sandbox can open known archive paths but cannot enumerate the mods folder.
This port reads `mods/mods.txt`, one relative `.o2r` or `.otr` filename per line.
Blank lines and lines beginning with `#` are ignored. Give each archive a unique
filename stem, including archives in subdirectories.

## OoT Reloaded

1. Download the **SoH O2R HD** release from
   [OoT Reloaded](https://github.com/GhostlyDark/OoT-Reloaded/releases/tag/v11.0.0).
2. Extract `OoT_Reloaded_v11.0.0_HD.o2r` into your title's `assets/mods/` folder.
   The 626 MB download expands to about 3.8 GiB; leave enough space on the console.
3. Generate the index on your PC:

   ```sh
   python3 tools/index-mods.py /path/to/PPSA99620/assets/mods
   ```

4. Upload the archives and `mods.txt` to
   `/mnt/ext1/etaHEN/games/PPSA99620/assets/mods/` and restart the title.
5. Enable **Use Alternate Assets** in SoH. Its config setting is
   `CVars.gSettings.AltAssets = 1`.

A `mods/mods.txt` in the writable data directory takes precedence over the bundled
manifest. SoH preserves mod priority in `CVars.gSettings.EnabledMods` (filename
stems separated by `|`); later-loaded archives override earlier ones. Use the mod
menu to put a prompt pack above a texture pack, or list its stem last in that CVar
before restarting. New archives are appended in path order.

## PlayStation prompts

`tools/make-playstation-prompts.py` builds an optional small prompt archive using
[Kenney Input Prompts](https://kenney.nl/assets/input-prompts), licensed CC0. It
downloads from a pinned source revision and includes the asset license. Pillow
is required (`python3 -m pip install Pillow`).

```sh
python3 tools/make-playstation-prompts.py /path/to/oot.o2r \
    /path/to/PPSA99620/assets/mods/PS5_PlayStation_Prompts.o2r \
    --cache /path/to/prompt-cache
python3 tools/index-mods.py /path/to/PPSA99620/assets/mods
```

The generator uses only texture dimensions from the base archive. It creates
dialogue, pause-menu, ocarina and empty C-slot prompts, plus English file-select
instructions. It does not change bindings. This layout matches the port's current
SDL defaults:

| PlayStation control | N64 action |
| --- | --- |
| Cross | A / action / confirm |
| Circle | B / sword / back |
| L2 | Z / targeting |
| R2 | R / shield |
| L1 | L |
| Right stick directions | C-buttons |
| Left stick | Movement |
| Options | Start |

Put `PS5_PlayStation_Prompts` last in `EnabledMods` to override Reloaded's glyphs.
Changing controller bindings requires a corresponding prompt mapping change.
HUD action words, shared button background colors and the controller editor's own
labels are preserved. The generated raw textures use byte-width conversion as well
as spatial scaling; a pixel-only `HByteScale` produces blank or truncated glyphs.
