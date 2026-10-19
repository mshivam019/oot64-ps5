# SPDX-License-Identifier: MIT
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch
try:
    from test_install_helpers import InstallTests as Fixtures, HELPER
except ModuleNotFoundError:
    from test_install import InstallTests as Fixtures, HELPER
sys.path.insert(0, str(HELPER.parent))
import ps5_store_setup as store


class StoreSetupTests(unittest.TestCase):
    setUp = Fixtures.setUp
    tearDown = Fixtures.tearDown
    disc = Fixtures.disc

    def test_prepares_and_validates_without_app_or_network(self):
        with patch('ftplib.FTP', side_effect=AssertionError('Store setup contacted console')):
            ready = store.prepare_store_game('PPSA99660', self.disc(), self.root)
        self.assertEqual((ready / 'data/rom/game.iso').read_bytes(), self.disc().read_bytes())
        report = json.loads((ready.parent / 'validation-report.json').read_text())
        self.assertTrue(report['ok'])
        self.assertEqual(report['mode'], 'game')
        self.assertFalse((ready / 'eboot.bin').exists())
        self.assertFalse((ready / 'validation-report.json').exists())

    def test_repeated_setup_preserves_prior_files_and_manifest(self):
        first = store.prepare_store_game('PPSA99660', self.disc(), self.root)
        previous = {p: p.read_bytes() for p in first.parent.rglob('*') if p.is_file()}
        second = store.prepare_store_game('PPSA99660', self.disc(), self.root)
        self.assertNotEqual(first.parent, second.parent)
        for p, contents in previous.items():
            self.assertEqual(p.read_bytes(), contents)

    def test_cancel_in_either_picker_writes_nothing(self):
        for choices in ([None], [self.root / 'game.iso', None]):
            with patch.object(store, 'choose_path', side_effect=choices), \
                 patch.object(store, 'prepare_store_game', side_effect=AssertionError('Preparation ran after cancellation')):
                store.store_setup_main('PPSA99660', [])
        self.assertEqual(list(self.root.iterdir()), [])

    def test_bad_disc_is_rejected_before_output_and_no_false_ready(self):
        with self.assertRaises(ValueError):
            store.prepare_store_game('PPSA99660', self.disc('GZ2E01'), self.root)
        self.assertFalse(list(self.root.glob('Ready*')))
        with patch.object(store, 'validate_prepared', return_value={'ok': False, 'errors': ['bad copy']}):
            with self.assertRaisesRegex(ValueError, 'Finished-folder validation failed'):
                store.prepare_store_game('PPSA99660', self.disc(), self.root)

    def test_text_fallback_and_entrypoint_need_no_title_id(self):
        disc = self.disc()
        with patch.object(store, 'choose_path', side_effect=OSError('Unavailable picker')), \
             patch('builtins.input', side_effect=[str(disc), str(self.root)]):
            store.store_setup_main('PPSA99660', ['--no-open'])
        script = HELPER.parent / 'store-setup.py'
        # The shared development tree has no game-specific wrapper; each release does.
        if script.is_file():
            result = subprocess.run([sys.executable, str(script), '--help'], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertNotIn('--title', result.stdout)


del Fixtures
