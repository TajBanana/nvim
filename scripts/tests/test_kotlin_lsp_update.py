"""Offline startup and source-selection regression tests."""
import importlib.util
import json
import os
import hashlib
import shutil
import tarfile
import sys
from pathlib import Path
import subprocess
import selectors
import time
import tempfile
import unittest
import zipfile

SCRIPTS = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('release', SCRIPTS / 'kotlin-lsp-release.py')
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)

LAUNCHER = '''#!/usr/bin/env python3
import json,sys,time
from pathlib import Path
mode = Path(__file__).with_name('mode').read_text()
if mode == 'expired':
    print('This build of intellij-server has expired.', file=sys.stderr)
    sys.exit(7)
if mode == 'timeout':
    time.sleep(10)
    sys.exit(1)
header = sys.stdin.buffer.readline()
length = int(header.split(b':')[1])
sys.stdin.buffer.readline()
sys.stdin.buffer.read(length)
response = {'jsonrpc': '2.0', 'id': 1}
if mode == 'error':
    response['error'] = {'code': -1, 'message': 'unrelated startup failure'}
else:
    response['result'] = {'capabilities': {}}
data = json.dumps(response).encode()
sys.stdout.buffer.write(f'Content-Length: {len(data)}\\r\\n\\r\\n'.encode() + data)
sys.stdout.buffer.flush()
time.sleep(10)
'''


class UpdateTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.dest = self.root / 'install'
        self.dest.mkdir()
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.github = '263.1.0'
        self.vsx = '263.2.0'
        self.old = '262.1.0'
        for build in (self.old, self.github, self.vsx):
            self.server(build, 'ready')
        (self.dest / 'current').symlink_to(self.dest / f'kotlin-server-{self.old}')
        self.release = {'tag_name': f'kotlin-lsp/v{self.github}', 'body': '\n'.join(
            f'https://download.jetbrains.com/kotlin-server-{self.github}{suffix}{checksum}'
            for suffix in ('.sit', '-aarch64.sit', '.tar.gz', '-aarch64.tar.gz')
            for checksum in ('', '.sha256'))}
        (self.root / 'github.json').write_text(json.dumps(self.release))
        self.bundle()
        curl = self.bin / 'curl'
        curl.write_text('''#!/usr/bin/env python3
import json,os,sys,shutil
from pathlib import Path
root=Path(os.environ['FIXTURES'])
url=next(a for a in sys.argv[1:] if a.startswith('https://'))
with (root/'calls').open('a') as log: log.write(url+'\\n')
if 'api.github.com' in url:
    if os.environ.get('FAIL_GITHUB'): sys.exit(22)
    print((root/'github.json').read_text())
elif url.endswith('.vsix'):
    shutil.copyfile(root/'extension.vsix', sys.argv[sys.argv.index('-o')+1])
elif url.endswith('/kotlin-server'):
    print(json.dumps({'version':'0.0.12'}))
elif url.endswith('.sha256'):
    print((root/'checksum').read_text())
elif (root/'archive').exists():
    shutil.copyfile(root/'archive', sys.argv[sys.argv.index('-o')+1])
else:
    sys.exit(22)
''')
        curl.chmod(0o755)
        self.env = dict(os.environ, FIXTURES=str(self.root), KOTLIN_LSP_HOME=str(self.dest),
                        PATH=str(self.bin) + os.pathsep + os.environ['PATH'])

    def server(self, build, mode):
        folder = self.dest / f'kotlin-server-{build}' / 'bin'
        folder.mkdir(parents=True, exist_ok=True)
        launcher = folder / 'intellij-server'
        launcher.write_text(LAUNCHER)
        launcher.chmod(0o755)
        (folder / 'mode').write_text(mode)
        return launcher

    def bundle(self):
        with zipfile.ZipFile(self.root / 'extension.vsix', 'w') as z:
            z.writestr('extension/server-bundle.json', json.dumps({
                'version': self.vsx, 'archiveName': f'kotlin-server-{self.vsx}.sit',
                'url': f'https://download.jetbrains.com/{self.vsx}.sit', 'sha256': 'a' * 64}))

    def run_update(self, answer='y'):
        return subprocess.run(['bash', str(SCRIPTS / 'update-kotlin-lsp.sh'), '--interactive'],
                              input=answer + '\n', env=self.env, text=True, capture_output=True, timeout=15)

    def assert_current(self, build):
        self.assertEqual((self.dest / 'current').resolve().name, f'kotlin-server-{build}')

    def stage_download(self, build=None):
        candidate = self.dest / f'kotlin-server-{build or self.github}'
        archive = self.root / 'archive'
        if sys.platform == 'darwin':
            with zipfile.ZipFile(archive, 'w') as z:
                for path in candidate.rglob('*'):
                    z.write(path, path.relative_to(self.dest))
        else:
            with tarfile.open(archive, 'w:gz') as tar:
                tar.add(candidate, arcname=candidate.name)
        (self.root / 'checksum').write_text(hashlib.sha256(archive.read_bytes()).hexdigest())
        shutil.rmtree(candidate)

    def test_download_verified_and_source_recorded(self):
        self.stage_download()
        result = self.run_update()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_current(self.github)
        metadata = json.loads((self.dest / 'current/install-source.json').read_text())
        self.assertEqual(metadata['source'], 'GitHub')
        self.assertEqual(metadata['version'], self.github)

    def test_checksum_failure_preserves_installation(self):
        self.stage_download()
        (self.root / 'checksum').write_text('0' * 64)
        result = self.run_update()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('MISMATCH', result.stderr)
        self.assert_current(self.old)
        self.assertNotIn('open-vsx', (self.root / 'calls').read_text())

    def test_preview_fetches_metadata_without_starting_or_installing(self):
        self.server(self.github, 'timeout')
        result = subprocess.run(['bash', str(SCRIPTS / 'update-kotlin-lsp.sh'), '--preview'],
                                env=self.env, text=True, capture_output=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(result.stdout.endswith(f'CANDIDATE kotlin-server-{self.github} GitHub\n'))
        self.assert_current(self.old)
        self.assertEqual(len((self.root / 'calls').read_text().splitlines()), 1)

    def test_github_preferred_even_when_vsx_newer(self):
        result = self.run_update()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_current(self.github)
        self.assertNotIn('open-vsx', (self.root / 'calls').read_text())
        self.assertTrue(result.stdout.endswith(f'UPDATED kotlin-server-{self.github}\n'))

    def test_expired_github_falls_back(self):
        self.server(self.github, 'expired')
        result = self.run_update()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_current(self.vsx)

    def test_declined_fallback_keeps_current(self):
        self.server(self.github, 'expired')
        self.stage_download(self.vsx)
        result = self.run_update('n')
        self.assertEqual(result.returncode, 20, result.stderr)
        self.assertIn(f'CONFIRM-OPEN-VSX {self.github} {self.vsx}', result.stdout)
        self.assertNotIn('checking Open VSX build', result.stdout)
        self.assertNotIn(f'https://download.jetbrains.com/{self.vsx}.sit', (self.root / 'calls').read_text())
        self.assert_current(self.old)

    def test_confirmed_fallback_download_records_open_vsx(self):
        self.server(self.github, 'expired')
        self.stage_download(self.vsx)
        with zipfile.ZipFile(self.root / 'extension.vsix') as z:
            bundle = json.loads(z.read('extension/server-bundle.json'))
        bundle['sha256'] = (self.root / 'checksum').read_text()
        if sys.platform != 'darwin':
            bundle['archiveName'] = f'kotlin-server-{self.vsx}.tar.gz'
        with zipfile.ZipFile(self.root / 'extension.vsix', 'w') as z:
            z.writestr('extension/server-bundle.json', json.dumps(bundle))
        result = self.run_update('y')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_current(self.vsx)
        metadata = json.loads((self.dest / 'current/install-source.json').read_text())
        self.assertEqual(metadata['source'], 'Open VSX')

    def test_confirmation_eof_is_dismissal(self):
        self.server(self.github, 'expired')
        self.assertEqual(self.run_update('').returncode, 20)
        self.assert_current(self.old)

    def test_no_implicit_confirmation_in_noninteractive_shell(self):
        self.server(self.github, 'expired')
        result = subprocess.run(['bash', str(SCRIPTS / 'update-kotlin-lsp.sh')],
                                input='', env=self.env, text=True, capture_output=True, timeout=15)
        self.assertEqual(result.returncode, 20)
        self.assert_current(self.old)

    def test_lock_held_while_confirmation_pending_and_released_after(self):
        self.server(self.github, 'expired')
        process = subprocess.Popen(['bash', str(SCRIPTS / 'update-kotlin-lsp.sh'), '--interactive'],
                                   env=self.env, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE)
        try:
            output = b''
            with selectors.DefaultSelector() as selector:
                selector.register(process.stdout, selectors.EVENT_READ)
                deadline = time.monotonic() + 10
                while b'CONFIRM-OPEN-VSX' not in output and time.monotonic() < deadline:
                    for key, _ in selector.select(0.25):
                        output += os.read(key.fileobj.fileno(), 65536)
            self.assertIn(b'CONFIRM-OPEN-VSX', output)
            self.assertEqual(self.run_update().returncode, 75)
            self.assert_current(self.old)
            process.communicate(b'n\n', timeout=5)
            self.assertEqual(process.returncode, 20)
            self.assertEqual(self.run_update('n').returncode, 20)
        finally:
            if process.poll() is None:
                process.kill()
                process.communicate()

    def test_both_expired_preserve_current(self):
        self.server(self.github, 'expired')
        self.server(self.vsx, 'expired')
        self.assertNotEqual(self.run_update().returncode, 0)
        self.assert_current(self.old)

    def test_same_expired_build_preserves_current(self):
        self.server(self.github, 'expired')
        self.vsx = self.github
        self.bundle()
        self.assertNotEqual(self.run_update().returncode, 0)
        self.assert_current(self.old)

    def test_other_startup_error_does_not_fall_back(self):
        self.server(self.github, 'error')
        self.assertNotEqual(self.run_update().returncode, 0)
        self.assertNotIn('open-vsx', (self.root / 'calls').read_text())
        self.assert_current(self.old)

    def test_github_network_error_does_not_fall_back(self):
        self.env['FAIL_GITHUB'] = '1'
        self.assertNotEqual(self.run_update().returncode, 0)
        self.assertNotIn('open-vsx', (self.root / 'calls').read_text())
        self.assert_current(self.old)

    def test_up_to_date_still_checks_expiry(self):
        (self.dest / 'current').unlink()
        (self.dest / 'current').symlink_to(self.dest / f'kotlin-server-{self.github}')
        result = self.run_update()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(result.stdout.endswith(f'UP-TO-DATE kotlin-server-{self.github}\n'))
        self.server(self.github, 'expired')
        self.assertEqual(self.run_update().returncode, 0)
        self.assert_current(self.vsx)

    def test_probe_timeout_is_not_expiry(self):
        launcher = self.server(self.github, 'timeout')
        self.assertEqual(release.probe(launcher, timeout=0.1), 1)

    def test_release_links_all_platforms(self):
        for target, suffix in {'darwin-arm64': '-aarch64.sit', 'darwin-x64': '.sit',
                               'linux-arm64': '-aarch64.tar.gz', 'linux-x64': '.tar.gz'}.items():
            bundle = release.github_bundle(self.release, target)
            self.assertTrue(bundle['url'].endswith(suffix))
            self.assertEqual(bundle['checksumUrl'], bundle['url'] + '.sha256')

    def test_missing_release_link_rejected(self):
        with self.assertRaises(ValueError):
            release.github_bundle({'tag_name': 'kotlin-lsp/v263.1.0', 'body': ''}, 'darwin-arm64')


if __name__ == '__main__':
    unittest.main()
