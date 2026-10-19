# SPDX-License-Identifier: MIT
try:
    from test_install_helpers import InstallTests as Fixtures, helper, HELPER
except ModuleNotFoundError:
    from test_install import InstallTests as Fixtures, helper, HELPER
import unittest
import json
from pathlib import Path
import subprocess
import sys
from unittest.mock import patch
import zipfile


class ValidationTests(unittest.TestCase):
    setUp = Fixtures.setUp
    tearDown = Fixtures.tearDown
    app = Fixtures.app
    disc = Fixtures.disc
    def prepare(self, mode='full'):
        args = ['--title', 'PPSA99660', '--output', str(self.root / 'ready')]
        if mode in ('app', 'full'):
            args += ['--app', str(self.app())]
        if mode in ('game', 'full'):
            args += ['--game', str(self.disc())]
        helper.prepare_main(args)
        return self.root / 'ready/PPSA99660', self.root / 'ready/MANIFEST-PPSA99660.json'

    def validate_cli(self, root, *args, ok=True):
        result = subprocess.run([sys.executable, str(HELPER.parent / 'validate-files.py'),
                                 '--src', str(root), *map(str, args)], capture_output=True, text=True)
        if ok:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0)
        return result

    def test_validation_modes_reports_and_read_only_network_free(self):
        for mode in ('app', 'game', 'full'):
            with self.subTest(mode=mode):
                root, manifest = self.prepare(mode)
                with patch.object(helper.ftplib, 'FTP', side_effect=AssertionError('Validator contacted network')):
                    before = {p: p.read_bytes() for p in self.root.rglob('*') if p.is_file()}
                    result = helper.validate_prepared(root, manifest)
                    after = {p: p.read_bytes() for p in self.root.rglob('*') if p.is_file()}
                self.assertTrue(result['ok'])
                self.assertEqual(result['mode'], mode)
                self.assertEqual(before, after)
                report = self.root / ('report-' + mode + '.json')
                self.validate_cli(root, '--require-complete', '--report', report, ok=mode == 'full')
                self.assertEqual(json.loads(report.read_text())['ok'], mode == 'full')
                self.validate_cli(root, '--report', report, ok=False)
                self.validate_cli(root, '--report', root / 'report.json', ok=False)
                import shutil
                shutil.rmtree(root.parent)

    def test_missing_same_size_corruption_and_wrong_nesting(self):
        root, manifest = self.prepare()
        disc = root / 'data/rom/game.iso'
        original = disc.read_bytes()
        damaged = bytearray(original)
        damaged[-1] ^= 1
        disc.write_bytes(damaged)
        result = self.validate_cli(root, ok=False)
        self.assertIn('SHA-256 mismatch: data/rom/game.iso', result.stdout)
        disc.unlink()
        self.assertIn('Missing file:', self.validate_cli(root, ok=False).stdout)
        self.validate_cli(root.parent, ok=False)
        disc.write_bytes(original)
        self.validate_cli(root, '--require-complete')
        extra = root / 'user/save.dat'
        extra.parent.mkdir()
        extra.write_bytes(b'private')
        report = helper.validate_prepared(root, manifest)
        self.assertTrue(report['ok'])
        self.assertEqual(report['untracked_files'], ['user/save.dat'])
        self.assertEqual(extra.read_bytes(), b'private')

    def test_invalid_manifests_cannot_escape_or_hide_required_files(self):
        root, manifest = self.prepare()
        data = json.loads(manifest.read_text())
        import copy
        for change in ('../outside', '/outside', 'C:/outside', 'bad\\path', 'a//b', 'a/./b'):
            invalid = copy.deepcopy(data)
            invalid['files'][0]['path'] = change
            manifest.write_text(json.dumps(invalid))
            with self.assertRaises(ValueError):
                helper.validate_prepared(root, manifest)
        for invalid in ([], {'schema': 2}, dict(data, title='PPSA99640'), dict(data, files=[]),
                        dict(data, files=data['files'] + [data['files'][0]])):
            manifest.write_text(json.dumps(invalid))
            with self.assertRaises(ValueError):
                helper.validate_prepared(root, manifest)
        # Even a newly forged valid checksum cannot hide invalid app metadata/layout.
        meta = root / 'sce_sys/param.json'
        meta.write_text('{"titleId":"PPSA99640"}')
        for entry in data['files']:
            if entry['path'] == 'sce_sys/param.json':
                entry.update(size=meta.stat().st_size, sha256=helper.digest(meta))
        data['files'] = [entry for entry in data['files'] if entry['path'] != 'eboot.bin']
        manifest.write_text(json.dumps(data))
        report = helper.validate_prepared(root, manifest)
        self.assertFalse(report['ok'])
        self.assertIn('App inventory is incomplete: eboot.bin', report['errors'])
        self.assertIn('App metadata title ID does not match the folder', report['errors'])

    def test_no_manifest_no_false_integrity_pass_and_no_symlinks(self):
        root, manifest = self.prepare()
        moved = self.root / 'original.json'
        manifest.rename(moved)
        self.assertIn('Missing original checksum manifest', self.validate_cli(root, ok=False).stderr)
        self.validate_cli(root, '--manifest', moved)
        (root / 'link').symlink_to(self.root / 'outside')
        self.validate_cli(root, '--manifest', moved, ok=False)

    def test_all_seven_full_title_layouts(self):
        for title in helper.PORTS:
            with self.subTest(title=title):
                source = self.root / ('input-' + title)
                if title in ('PPSA99640', 'PPSA99660'):
                    source = self.disc('GZ2E01' if title == 'PPSA99640' else 'GAFE01')
                elif title in ('PPSA99620', 'PPSA99621'):
                    source = source / ('oot.o2r' if title == 'PPSA99620' else 'mm.o2r')
                    source.parent.mkdir()
                    with zipfile.ZipFile(source, 'w') as archive:
                        archive.writestr('asset', b'asset')
                else:
                    names = ({'PPSA99630': ['Morrowind.esm', 'Tribunal.esm', 'Bloodmoon.esm',
                                           'Morrowind.bsa', 'Tribunal.bsa', 'Bloodmoon.bsa'],
                              'PPSA99641': ['game.wwhd', 'code/cking.rpx', 'content/a', 'meta/a'],
                              'PPSA99670': ['game.la', 'exefs/main', 'exefs/sdk', 'romfs.bin', 'romfs/region_common/a']}[title])
                    for name in names:
                        file = source / name
                        file.parent.mkdir(parents=True, exist_ok=True)
                        file.write_bytes(b'synthetic layout fixture')
                out = self.root / ('ready-' + title)
                helper.prepare_main(['--title', title, '--app', str(self.app(title)),
                                     '--game', str(source), '--output', str(out)])
                result = helper.validate_prepared(out / title, out / ('MANIFEST-' + title + '.json'))
                self.assertTrue(result['ok'], result)
                self.assertEqual(result['mode'], 'full')

    def test_damaged_o2r_crc_and_empty_archive_rejected(self):
        p = self.root / 'oot.o2r'
        with zipfile.ZipFile(p, 'w', compression=zipfile.ZIP_STORED) as archive:
            archive.writestr('asset', b'KNOWN-ASSET-CONTENT')
        p.write_bytes(p.read_bytes().replace(b'KNOWN-ASSET-CONTENT', b'KNOWN-ASSET-CORRUPT'))
        with self.assertRaises((ValueError, zipfile.BadZipFile)):
            helper.game_files('PPSA99620', p)
        with zipfile.ZipFile(p, 'w'):
            pass
        with self.assertRaises(ValueError):
            helper.game_files('PPSA99620', p)


del Fixtures
