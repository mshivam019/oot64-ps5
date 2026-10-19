#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Shivam Mishra
"""Game-specific local setup for users who already installed the app from a store."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

from ps5_install_lib import PORTS, prepare_main, validate_prepared

FOLDER_INPUTS = {'PPSA99630', 'PPSA99641', 'PPSA99670'}


def prepare_store_game(title, game, parent):
    """Reuse preparation and validation; return a fresh data-only title folder."""
    if not parent.is_dir():
        raise ValueError('Choose an existing output folder on your computer or USB drive')
    name = 'Ready - ' + PORTS[title][0]
    output = parent / name
    number = 2
    while output.exists() or output.is_symlink():
        output = parent / (name + ' (' + str(number) + ')')
        number += 1
    prepare_main(['--title', title, '--game', str(game), '--output', str(output)])
    print('\nChecking the finished folder automatically...', flush=True)
    result = validate_prepared(output / title, output / ('MANIFEST-' + title + '.json'))
    with (output / 'validation-report.json').open('x', encoding='utf-8') as stream:
        json.dump(result, stream, indent=2)
        stream.write('\n')
    if not result['ok']:
        raise ValueError('Finished-folder validation failed: ' + '; '.join(result['errors']))
    print('\nREADY: ' + PORTS[title][0] + ' game files passed the copy and layout checks.')
    print('Your app is already installed from the store. Copy the CONTENTS of:')
    print(str((output / title).resolve()))
    print('into that installed title folder using your preferred file-copy method.')
    print('Keep the manifest and report on your computer. Transfer is a separate step.')
    return output / title


def choose_path(title, folder):
    """Use existing OS file pickers. None means the user cancelled."""
    if sys.platform == 'win32':
        dialog_type = 'FolderBrowserDialog' if folder else 'OpenFileDialog'
        selected = 'SelectedPath' if folder else 'FileName'
        label = title.replace("'", "''")
        property_name = 'Description' if folder else 'Title'
        script = (
            '[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false); '
            'Add-Type -AssemblyName System.Windows.Forms; '
            '$dialog = New-Object System.Windows.Forms.' + dialog_type + '; '
            '$dialog.' + property_name + " = '" + label + "'; "
            'if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) '
            '{ [Console]::Write($dialog.' + selected + '); $dialog.Dispose() } '
            'else { $dialog.Dispose(); exit 1 }'
        )
        command = ['powershell.exe', '-NoProfile', '-STA', '-Command', script]
    elif sys.platform == 'darwin':
        script = 'POSIX path of (choose ' + ('folder' if folder else 'file') + ' with prompt ' + json.dumps(title) + ')'
        command = ['osascript', '-e', script]
    elif (os.environ.get('DISPLAY') or os.environ.get('WAYLAND_DISPLAY')) and shutil.which('zenity'):
        command = ['zenity', '--file-selection', '--title=' + title]
        if folder:
            command += ['--directory']
    elif (os.environ.get('DISPLAY') or os.environ.get('WAYLAND_DISPLAY')) and shutil.which('kdialog'):
        command = ['kdialog', '--title', title,
                   '--getexistingdirectory' if folder else '--getopenfilename', str(Path.home())]
    else:
        raise OSError('No native file picker is available')
    result = subprocess.run(command, capture_output=True, text=True, encoding='utf-8', errors='replace')
    if result.returncode == 1 and (sys.platform != 'darwin' or '-128' in result.stderr):
        return None
    if result.returncode != 0:
        raise OSError('The file picker could not open: ' + result.stderr.strip())
    value = result.stdout.strip()
    return Path(value) if value else None


def reveal_folder(path):
    if sys.platform == 'win32':
        os.startfile(str(path))
    else:
        command = ['open' if sys.platform == 'darwin' else 'xdg-open', str(path)]
        subprocess.run(command, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def store_setup_main(title, argv=None):
    name, kind, _ = PORTS[title]
    parser = argparse.ArgumentParser(description='Prepare and check ' + name + ' game data for an app already installed from ProsperoStore. No console connection.')
    parser.add_argument('--game', type=Path, help='Game file or prepared folder; opens a native picker when omitted')
    parser.add_argument('--output', type=Path, help='Existing parent folder on this computer or USB; output is always new')
    parser.add_argument('--text', action='store_true', help='Use text prompts instead of native file pickers')
    parser.add_argument('--no-open', action='store_true', help='Do not open the finished folder in a file manager')
    args = parser.parse_args(argv)
    print(name + ' — game files for your store-installed app', flush=True)
    print('Choose ' + kind + '. No app ZIP or title ID entry is needed.', flush=True)
    if title in ('PPSA99641', 'PPSA99670'):
        print('Use the prepared folder from this game\'s matching setup bundle; this step does not compile game modules.', flush=True)
    if title in ('PPSA99620', 'PPSA99621'):
        print('Use the archive exported by the matching desktop port; a raw ROM still needs conversion first.', flush=True)
    def ask(prompt, folder):
        if not args.text:
            try:
                return choose_path(prompt, folder)
            except OSError as error:
                print(str(error) + '. Use the text prompt below.', flush=True)
        value = input(prompt + ' (blank to cancel): ').strip().strip('"').strip("'")
        return Path(value) if value else None
    game = args.game or ask(name + ': choose ' + kind, title in FOLDER_INPUTS)
    if game is None:
        print('Cancelled. No files prepared.')
        return
    parent = args.output or ask(name + ': choose where to put the ready folder', True)
    if parent is None:
        print('Cancelled. No files prepared.')
        return
    ready = prepare_store_game(title, game, parent)
    if not args.no_open:
        try:
            reveal_folder(ready)
        except (OSError, subprocess.SubprocessError):
            print('Open the ready folder shown above in your file manager.')
