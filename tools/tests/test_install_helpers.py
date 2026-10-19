# SPDX-License-Identifier: MIT
import importlib.util
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import threading
import unittest
from unittest.mock import patch
import zipfile

HERE = Path(__file__).resolve().parents[1]
HELPER = next(p for p in (HERE / 'helper/ps5_install_lib.py', HERE / 'ps5_install_lib.py') if p.is_file())
spec = importlib.util.spec_from_file_location('install_helper', HELPER)
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


class InstallTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)

    def tearDown(self):
        self.temporary.cleanup()

    def disc(self, title='GAFE01'):
        data = bytearray(4096)
        data[:6] = title.encode()
        data[0x1c:0x20] = bytes.fromhex('c2339f3d')
        struct.pack_into('>III', data, 0x420, 0x500, 0x800, 12)
        p = self.root / 'My Game.ISO'
        p.write_bytes(data)
        return p

    def app(self, title='PPSA99660', unsafe=None):
        p = self.root / 'app.zip'
        with zipfile.ZipFile(p, 'w') as z:
            z.writestr(title + '/eboot.bin', b'executable')
            z.writestr(title + '/sce_sys/icon0.png', b'icon')
            z.writestr(title + '/sce_sys/param.json', json.dumps({'titleId': title}))
            z.writestr(title + '/user/save.dat', b'private save')
            if unsafe:
                z.writestr(unsafe, b'unsafe')
        return p

    def run_helper(self, *args, ok=True):
        script = HELPER.parent / ('transfer-files.py' if '--console' in args else 'prepare-files.py')
        result = subprocess.run([sys.executable, str(script), *map(str, args)],
                                text=True, capture_output=True)
        if ok:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout)
        return result

    def test_preparation_never_connects_and_produces_only_ready_files(self):
        source = self.disc()
        app = self.app()
        out = self.root / 'ready'
        with patch.object(helper.ftplib, 'FTP', side_effect=AssertionError('Preparation contacted network')):
            helper.prepare_main(['--title', 'PPSA99660', '--app', str(app),
                                 '--game', str(source), '--output', str(out)])
        ready = out / 'PPSA99660'
        self.assertTrue((ready / 'eboot.bin').is_file())
        self.assertTrue((ready / 'data/rom/game.iso').is_file())
        self.assertFalse(any(p.suffix == '.py' for p in ready.rglob('*')))
        self.assertIn('Full app', (out / 'COPY-PPSA99660-TO-PS5.txt').read_text())
        with patch.object(helper, 'game_files', side_effect=AssertionError('Transfer prepared game data')), \
             patch.object(helper, 'unpack_app', side_effect=AssertionError('Transfer unpacked an app')), \
             patch.object(helper.ftplib, 'FTP', side_effect=AssertionError('Dry run contacted network')):
            helper.transfer_main(['--src', str(ready), '--console', '127.0.0.1',
                                  '--remote-dir', '/data/homebrew/PPSA99660', '--check'])

    def test_animal_disc_offline_without_app_network_or_m2(self):
        disc = self.disc()
        out = self.root / 'USB Drive'
        self.run_helper('--title', 'PPSA99660', '--game', disc, '--output', out)
        copied = out / 'PPSA99660/data/rom/game.iso'
        self.assertEqual(copied.read_bytes(), disc.read_bytes())
        self.assertTrue(disc.exists())
        # Preserve an already staged installation, even when rerun.
        copied.write_bytes(b'keep me')
        self.run_helper('--title', 'PPSA99660', '--game', disc, '--output', out, ok=False)
        self.assertEqual(copied.read_bytes(), b'keep me')

    def test_gamecube_wrong_revision_and_truncation_rejected_before_output(self):
        p = self.disc()
        out = self.root / 'out'
        self.run_helper('--title', 'PPSA99640', '--game', p, '--output', out, ok=False)
        self.assertFalse(out.exists())
        p.write_bytes(p.read_bytes()[:0x480])
        self.run_helper('--title', 'PPSA99660', '--game', p, '--output', out, ok=False)
        self.assertFalse(out.exists())

    def test_twilight_raw_disc(self):
        p = self.disc('GZ2E01')
        self.run_helper('--title', 'PPSA99640', '--game', p, '--output', self.root / 'out')
        self.assertEqual((self.root / 'out/PPSA99640/game.iso').read_bytes(), p.read_bytes())

    def test_catalog_zip_and_save_exclusion(self):
        out = self.root / 'out'
        self.run_helper('--title', 'PPSA99660', '--app', self.app(), '--output', out)
        self.assertTrue((out / 'PPSA99660/eboot.bin').is_file())
        self.assertFalse((out / 'PPSA99660/user').exists())

    def test_shipped_dusklight_default_config_is_present_without_personal_saves(self):
        app = self.app('PPSA99640')
        with zipfile.ZipFile(app, 'a') as z:
            z.writestr('PPSA99640/user/config.json', '{"fps":60}')
        out = self.root / 'out'
        self.run_helper('--title', 'PPSA99640', '--app', app, '--output', out)
        self.assertEqual((out / 'PPSA99640/user/config.json').read_text(), '{"fps":60}')
        self.assertFalse((out / 'PPSA99640/user/save.dat').exists())

    def test_zip_traversal_and_wrong_title_rejected(self):
        for unsafe in ('../../escape', '/absolute', 'PPSA99660/../escape', 'C:/escape', 'bad\\path'):
            self.run_helper('--title', 'PPSA99660', '--app', self.app(unsafe=unsafe),
                            '--output', self.root / 'out', ok=False)
            self.assertFalse((self.root / 'out').exists())
        self.run_helper('--title', 'PPSA99660', '--app', self.app('PPSA99640'),
                        '--output', self.root / 'out', ok=False)

    def test_ocarina_and_majora_preserve_archive_bytes(self):
        for title, name in (('PPSA99620', 'oot.o2r'), ('PPSA99621', 'mm.o2r')):
            source = self.root / name
            with zipfile.ZipFile(source, 'w') as z:
                z.writestr('assets/test', b'test asset')
            self.run_helper('--title', title, '--game', source, '--output', self.root / 'out')
            self.assertEqual((self.root / 'out' / title / 'assets' / name).read_bytes(), source.read_bytes())

    def test_morrowind_case_normalization_and_required_expansions(self):
        data = self.root / 'Morrowind/Data Files'
        data.mkdir(parents=True)
        names = ('Morrowind.esm', 'Tribunal.esm', 'Bloodmoon.esm',
                 'Morrowind.bsa', 'Tribunal.bsa', 'Bloodmoon.bsa')
        for name in names:
            (data / name.lower()).write_bytes(name.encode())
        nested = data / 'Textures'
        nested.mkdir()
        (nested / 'a texture.dds').write_bytes(b'texture')
        out = self.root / 'out'
        self.run_helper('--title', 'PPSA99630', '--game', data.parent, '--output', out)
        self.assertTrue((out / 'PPSA99630/assets/Data Files/Morrowind.esm').is_file())
        self.assertTrue((out / 'PPSA99630/assets/Data Files/Textures/a texture.dds').is_file())
        (data / 'tribunal.esm').unlink()
        self.run_helper('--title', 'PPSA99630', '--game', data, '--output', self.root / 'other', ok=False)

    def test_prepared_modules_import_only_game_data(self):
        for title, directory, required in (
            ('PPSA99641', 'game', ['game.wwhd', 'code/cking.rpx', 'content/a', 'meta/a']),
            ('PPSA99670', 'extracted', ['game.la', 'exefs/main', 'exefs/sdk', 'romfs.bin', 'romfs/region_common/a'])):
            source = self.root / title
            for name in required:
                p = source / directory / name
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_bytes(name.encode())
            (source / 'user').mkdir()
            (source / 'user/save').write_bytes(b'private save')
            out = self.root / 'out'
            self.run_helper('--title', title, '--game', source, '--output', out)
            self.assertFalse((out / title / 'user').exists())
            for name in required:
                self.assertEqual((out / title / directory / name).read_bytes(), name.encode())

    def test_symlink_rejected_and_check_writes_nothing(self):
        source = self.root / 'source'
        source.mkdir()
        with zipfile.ZipFile(source / 'oot.o2r', 'w') as z:
            z.writestr('a', b'a')
        (source / 'link.o2r').symlink_to(source / 'oot.o2r')
        self.run_helper('--title', 'PPSA99620', '--game', source / 'link.o2r',
                        '--output', self.root / 'out', ok=False)
        self.run_helper('--title', 'PPSA99620', '--game', source / 'oot.o2r',
                        '--output', self.root / 'out', '--check')
        self.assertFalse((self.root / 'out').exists())

    def test_real_ftp_internal_storage_preservation_replacement_and_backups(self):
        from pyftpdlib.authorizers import DummyAuthorizer
        from pyftpdlib.handlers import FTPHandler
        from pyftpdlib.servers import FTPServer
        root = self.root / 'remote'
        root.mkdir()
        auth = DummyAuthorizer()
        auth.add_anonymous(str(root), perm='elradfmwMT')
        class Handler(FTPHandler):
            transformed_size_seen = False
            def ftp_SIZE(self, path):
                if 'eboot.bin.upload-' in path:
                    Handler.transformed_size_seen = True
                    self.respond('213 999999')  # Simulate decoded SELF size; MLSD retains stored size.
                    return
                return super().ftp_SIZE(path)
        Handler.authorizer = auth
        server = FTPServer(('127.0.0.1', 0), Handler)
        port = server.socket.getsockname()[1]
        thread = threading.Thread(target=server.serve_forever, kwargs={'timeout': .05}, daemon=True)
        thread.start()
        self.run_helper('--title', 'PPSA99660', '--app', self.app(), '--game', self.disc(), '--output', self.root / 'ready')
        args = ('--src', self.root / 'ready/PPSA99660', '--console', '127.0.0.1',
                '--ftp-port', port, '--remote-dir', '/data/homebrew/PPSA99660')
        try:
            self.run_helper(*args, ok=False)  # Requires explicit closed-game acknowledgement.
            self.run_helper(*args, '--closed')
            target = root / 'data/homebrew/PPSA99660/data/rom/game.iso'
            self.assertEqual(target.read_bytes(), self.disc().read_bytes())
            self.assertTrue(Handler.transformed_size_seen)
            self.assertEqual((root / 'data/homebrew/PPSA99660/eboot.bin').read_bytes(), b'executable')
            target.write_bytes(b'prior game file')
            config_source = self.root / 'ready/PPSA99660/assets/settings.cfg'
            config_source.parent.mkdir(parents=True)
            config_source.write_text('new default')
            config_target = root / 'data/homebrew/PPSA99660/assets/settings.cfg'
            config_target.parent.mkdir(parents=True)
            config_target.write_text('custom settings')
            save = target.parents[2] / 'save-file'
            save.write_bytes(b'save untouched')
            self.run_helper(*args, '--closed')
            self.assertEqual(target.read_bytes(), b'prior game file')
            self.run_helper(*args, '--closed', '--replace-existing')
            backups = list(target.parent.glob('game.iso.before-install-*'))
            self.assertEqual(len(backups), 1)
            self.assertEqual(backups[0].read_bytes(), b'prior game file')
            self.assertEqual(save.read_bytes(), b'save untouched')
            self.assertEqual(config_target.read_text(), 'custom settings')
            bad = list(args)
            bad[-1] = '/data/homebrew'
            self.run_helper(*bad, '--closed', ok=False)
        finally:
            server.close_all()
            thread.join(2)


if __name__ == '__main__':
    unittest.main()
