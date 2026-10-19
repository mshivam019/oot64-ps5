# Install Ocarina of Time on PS5

**You do not need M.2 storage, a wired LAN cable or PS5 Upload specifically.**
You need a homebrew-capable PS5 with compatible native-title support and enough
space at your chosen installation location. Keep your existing jailbreak/loader.

## Game files for PPSA99620

Run [desktop Ship of Harkinian 9.2.3](https://github.com/HarbourMasters/Shipwright/releases/tag/9.2.3) with your own supported ROM and let it finish extraction. Close it and copy **oot.o2r**. You do not need a PS5 SDK or to build the PS5 app.

Put them **inside the installed PPSA99620 folder**, at:

```text
PPSA99620/assets/oot.o2r
```

## Choose where to install

Use the folder selected by your **existing native-title loader or ProsperoStore**.
Internal storage is an option: a loader that scans `/data/homebrew` can use
`/data/homebrew/PPSA99620`. M.2 and USB locations depend on your loader and settings;
copy to the path it actually uses. `/mnt/ext1` is an M.2 example, not a requirement.
For a store installation, find the existing `PPSA99620` folder before adding data;
do not make a second copy on another drive and expect the store app to see it.

PS5 Upload is optional. Ethernet is optional. With FTP, a PC and PS5 on the same
home Wi-Fi network can transfer files; enter the PS5's current IP and the port
shown by its FTP server. No changes to internet sharing or router settings are
part of this setup. With USB, use your console file manager to copy from the USB
drive to the installed title folder. Loader/firmware/file-manager support varies;
not every loader can run titles directly from every USB format or path.

## Already installed from ProsperoStore?

1. Save and close the game.
2. Find the installed `PPSA99620` folder. It contains `eboot.bin` and `sce_sys/`.
3. Add **only the game files described above**, at the specified relative path.
4. Start the existing home-screen tile. Do not reinstall the app to add game files.

## Installing manually, including without a network

1. Download **PPSA99620.zip** from the release. It is a precompiled PS5 app, not
   source code. Unpack the whole `PPSA99620` folder, including `sce_sys/icon0.png`
   and `sce_module/` when present. Windows/Linux installer ZIPs contain the same
   app under `output/PPSA99620`.
2. Add your game files at the path shown above.
3. Copy the completed title folder using either ordinary FTP over Wi-Fi/Ethernet,
   or a USB drive plus your console file manager. A supported USB filesystem with
   enough space for the largest file is needed; FAT32 cannot hold files >=4 GiB.
4. Put it in a location your existing native-title loader scans, then refresh,
   mount or register it using that loader. Copying files and registering a title
   are separate steps; FTP and the helper do not register it automatically.

For offline use, download the app and any game-preparation tools first. A local
prepared USB folder does not install itself just by plugging the drive in.

## Optional common file helper

[Download PS5-Install-Helper-v1.0.0.zip](https://github.com/mshivam019/oot64-ps5/releases/download/v1.2.0/PS5-Install-Helper-v1.0.0.zip).
It runs on a computer with **Python 3.9+**, uses only the standard library, and
needs no PS5 SDK, PS5 Upload or extra Python packages. The game-specific converter
requirements above still apply. Manual copying does not require this helper.

Double-click **Prepare-Files-Windows.cmd**, or run `sh prepare-files.sh` on
Linux/macOS, then answer the prompts. Select the existing prepared game data,
and optionally an app ZIP if it is not already installed. Choose a new output
folder on your computer or USB drive.

**Preparation and transfer are separate files.** `prepare-files.py` never contacts
the console; game-module compilation remains in the matching game setup bundle.
It creates a normal `PPSA99620/` folder with the correct layout and
checks copied files with SHA-256. Copy the **contents** of that folder
into the installed title folder; do not nest `PPSA99620` inside another `PPSA99620`.
Personal saves are excluded. A shipped default configuration needed by a fresh
app may be included; FTP preserves existing configuration even with --replace-existing.
It accepts data from an older prepared folder without requiring recompilation;
keep generated game modules matched to the app/setup release that created them.

Command-line example (change the paths):

```sh
python3 prepare-files.py --title PPSA99620 --game "/path/to/oot.o2r" --output "/path/to/USB-or-local-output"
```

Add `--app "/path/to/PPSA99620.zip"` for a complete app-plus-game staging folder.
Add `--check` to validate inputs and see the plan before copying.

Only after preparation finishes, optional FTP transfer is a separate command:

```sh
python3 transfer-files.py --src "/path/to/ready/PPSA99620" --console YOUR_PS5_IP --ftp-port 2121 --remote-dir "/YOUR/INSTALLED/PATH/PPSA99620" --closed
```

`transfer-files.py` does not compile, extract or prepare game files. You can skip
it entirely and copy the ready folder with any method you prefer.

`--remote-dir` is required and includes the title ID. There is no assumed M.2
path. Use `--ftp-user USERNAME` if the server requires a login (password is asked
privately). `--closed` confirms you saved and closed this game yourself. Existing
remote files are kept by default. `--replace-existing` replaces only selected
files and keeps `.before-install-*` backups. It never closes apps, deletes remote
folders or operates on another title.

FTP completion is checked against server-reported file sizes, not a full readback
hash. If a server exposes a decoded executable size and cannot provide its stored
size, app transfer stops with the original intact. Use local/USB copying or
another compatible FTP server. Game-data-only transfer avoids uploading the app.

## Updates and recovering game files

Keep saves, configuration, mods and separately prepared game data. When copying
an app update manually, merge app files; do not delete the entire installed folder.
ProsperoStore updates can replace the app folder and move the old one (including
added game files) to `/data/prosperostore/previous/PPSA99620` or
`prosperostore/previous/PPSA99620` on that app's drive. If a game asks for data after
an update, restore **the game files above** from that previous folder or your
private backup into the new title folder. Preserve the current saves/settings;
do not replace the whole new app with the old folder. Recover those files before
another store update replaces the previous backup.

## If it does not start

- **Missing game data:** check the exact relative path and avoid an extra nested
  title folder. A store app contains no commercial game data.
- **Wrong revision/package:** use the supported revision and matching converter;
  renaming a compressed dump does not unpack it.
- **FTP cannot connect:** check the IP/port displayed by the console server and
  that both devices can reach each other. Wired LAN and PS5 Upload are not prerequisites.
- **No home-screen tile:** confirm your loader scans the destination and that
  the whole `sce_sys/` folder was copied, then refresh/register with that loader.
- **Helper says it kept existing files:** it did not replace those files. Check
  your selection/version before deliberately using `--replace-existing`.
- **Game data vanished after a store update:** see recovery above.

When reporting a problem, give the game/app version, loader, storage location,
transfer method, exact failing step and error text. Do not send dumps, keys or saves.

The file helper has local-copy and ordinary-FTP integration tests on Linux.
Native Windows/macOS execution and internal/USB console gameplay have not been
verified for this update. Existing gameplay testing used the developer's firmware
9.00 setup; this guide does not claim every firmware/loader combination works.

Implementation references: [store locations/update behavior](https://github.com/darkxex/ProsperoStore#features),
[manual title-folder setup in Rush 2](https://github.com/Marice/rush2-ps5#installing),
and [USB/file-manager copying](https://github.com/SvenGDK/Prospero-Explorer#what-it-does).
The helper is original MIT-licensed Python code; it does not embed these projects.
