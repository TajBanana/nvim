# Run: python3 -B scripts/tests/test_kotlin_lsp_update.py
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
        # A fake, empty process list by default: the prune step reads `ps`, and
        # the machine's real processes (a Kotlin server open in Neovim runs as
        # ".../current/bin/intellij-server") must not change test outcomes.
        self.fake_ps('echo "/sbin/launchd"\n')

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

    def run_rollback(self):
        return subprocess.run(['bash', str(SCRIPTS / 'update-kotlin-lsp.sh'), 'rollback'],
                              env=self.env, text=True, capture_output=True, timeout=15)

    def assert_previous(self, build):
        self.assertEqual((self.dest / 'previous').resolve().name, f'kotlin-server-{build}')

    def test_update_keeps_previous_build_and_prunes_older(self):
        result = self.run_update()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_current(self.github)
        self.assert_previous(self.old)
        self.assertTrue((self.dest / f'kotlin-server-{self.old}').is_dir())
        # Neither current nor the rollback target: pruned.
        self.assertFalse((self.dest / f'kotlin-server-{self.vsx}').exists())

    def test_rollback_swaps_current_and_previous(self):
        self.assertEqual(self.run_update().returncode, 0)
        result = self.run_rollback()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(result.stdout.endswith(f'ROLLED-BACK kotlin-server-{self.old}\n'))
        self.assert_current(self.old)
        self.assert_previous(self.github)
        # Rolling back again returns to the newer build.
        self.assertEqual(self.run_rollback().returncode, 0)
        self.assert_current(self.github)
        self.assert_previous(self.old)

    def test_rollback_refuses_expired_previous(self):
        self.assertEqual(self.run_update().returncode, 0)
        self.server(self.old, 'expired')
        result = self.run_rollback()
        self.assertEqual(result.returncode, 14, result.stderr)
        self.assertIn('has expired', result.stderr)
        self.assert_current(self.github)

    def test_rollback_without_previous_build(self):
        result = self.run_rollback()
        self.assertEqual(result.returncode, 13, result.stderr)
        self.assert_current(self.old)

    def test_rollback_refuses_when_previous_is_current(self):
        # current == previous must not "succeed" (probe, restart) doing nothing.
        (self.dest / 'previous').symlink_to(self.dest / f'kotlin-server-{self.old}')
        result = self.run_rollback()
        self.assertEqual(result.returncode, 13, result.stderr)
        self.assertIn('already current', result.stderr)
        self.assert_current(self.old)

    def test_rollback_drops_dangling_previous(self):
        (self.dest / 'previous').symlink_to(self.dest / 'kotlin-server-1.0.0')
        result = self.run_rollback()
        self.assertEqual(result.returncode, 13, result.stderr)
        self.assertFalse(os.path.lexists(self.dest / 'previous'))
        self.assert_current(self.old)

    def test_rollback_to_previous_outside_install_dir(self):
        # A valid previous build kept elsewhere: it used to be looked up as
        # "$DEST/<basename>", judged dangling, and its link deleted.
        elsewhere = self.root / 'elsewhere'
        elsewhere.mkdir()
        shutil.move(str(self.dest / f'kotlin-server-{self.vsx}'), str(elsewhere))
        (self.dest / 'previous').symlink_to(elsewhere / f'kotlin-server-{self.vsx}')
        result = self.run_rollback()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.dest / 'current').resolve(), (elsewhere / f'kotlin-server-{self.vsx}').resolve())
        self.assert_previous(self.old)

    def test_messages_name_a_current_that_is_not_a_link(self):
        # `current` as a plain directory: the messages printed an empty name
        # ("Keeping .").
        (self.dest / 'current').unlink()
        shutil.copytree(self.dest / f'kotlin-server-{self.github}', self.dest / 'current')
        (self.dest / 'previous').symlink_to(self.dest / f'kotlin-server-{self.old}')
        self.server(self.old, 'expired')
        result = self.run_rollback()
        self.assertEqual(result.returncode, 14, result.stderr)
        self.assertIn('Keeping the current installation.', result.stderr)

    def test_update_with_dangling_current_prunes_nothing(self):
        # `current` pointing at a build that does not exist (as a test once left
        # it): no previous is recorded, so pruning would delete the only
        # working build.
        (self.dest / 'current').unlink()
        (self.dest / 'current').symlink_to(self.dest / 'kotlin-server-1.0.0')
        self.stage_download()
        result = self.run_update()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_current(self.github)
        self.assertTrue((self.dest / f'kotlin-server-{self.old}').is_dir(), 'the old working build was pruned')
        self.assertTrue((self.dest / f'kotlin-server-{self.vsx}').is_dir())
        self.assertIn('did not point at a working build', result.stderr)

    def test_rollback_needs_no_curl_or_unzip(self):
        self.assertEqual(self.run_update().returncode, 0)
        # A PATH holding only the tools rollback uses -- no curl, no unzip.
        tools = self.root / 'tools'
        tools.mkdir()
        for name in ('bash', 'python3', 'basename', 'readlink', 'dirname', 'mktemp', 'rm', 'uname', 'mkdir'):
            (tools / name).symlink_to(shutil.which(name))
        env = dict(self.env, PATH=str(tools))
        result = subprocess.run([str(tools / 'bash'), str(SCRIPTS / 'update-kotlin-lsp.sh'), 'rollback'],
                                env=env, text=True, capture_output=True, timeout=15)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_current(self.old)

    def test_relative_install_dir_links_resolve(self):
        self.stage_download()
        env = dict(self.env, KOTLIN_LSP_HOME='install')
        result = subprocess.run(['bash', str(SCRIPTS / 'update-kotlin-lsp.sh'), '--interactive'], cwd=self.root,
                                input='y\n', env=env, text=True, capture_output=True, timeout=15)
        self.assertEqual(result.returncode, 0, result.stderr)
        # Links must not be relative to their own directory (dangling).
        self.assertTrue((self.dest / 'current' / 'bin' / 'intellij-server').exists())
        self.assertTrue((self.dest / 'previous' / 'bin' / 'intellij-server').exists())

    def test_prune_keeps_build_used_by_running_server(self):
        # A server started from a versioned build directory (by hand, or by
        # another tool) is recognised and its build kept. The resolved path is
        # used because the temp dir sits behind a symlink on macOS
        # (/var -> /private/var). A fake process list keeps the machine's real
        # processes out of the result.
        in_use = self.dest.resolve() / f'kotlin-server-{self.vsx}' / 'bin' / 'intellij-server'
        self.fake_ps(f'echo "{in_use} --stdio"\n')
        result = self.run_update()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(in_use.exists(), 'a build a running server uses was pruned')
        self.assertIn('a running server uses it', result.stderr)

    def fake_ps(self, body):
        ps = self.bin / 'ps'
        ps.write_text('#!/bin/sh\n' + body)
        ps.chmod(0o755)

    def test_prune_match_early_in_long_process_list(self):
        # The old `printf | grep -q` died of SIGPIPE when the match came early in
        # a long listing, and pipefail turned "in use" into "not in use".
        in_use = self.dest.resolve() / f'kotlin-server-{self.vsx}'
        self.fake_ps(f'echo "{in_use}/bin/intellij-server --stdio"\n'
                     'i=0; while [ $i -lt 200000 ]; do echo "filler process $i"; i=$((i+1)); done\n')
        result = self.run_update()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(in_use.exists(), 'in-use build pruned (SIGPIPE false negative)')

    def test_prune_through_symlinked_install_dir(self):
        # A server launched from the RESOLVED versioned path (by hand, or by
        # another tool -- Neovim itself launches through `current`); DEST behind
        # a symlink (or with a trailing slash) never matched it.
        link = self.root / 'link'
        link.symlink_to(self.dest)
        in_use = self.dest.resolve() / f'kotlin-server-{self.vsx}'
        self.fake_ps(f'echo "{in_use}/bin/intellij-server --stdio"\n')
        for home in (str(link), str(link) + '/'):
            env = dict(self.env, KOTLIN_LSP_HOME=home)
            result = subprocess.run(['bash', str(SCRIPTS / 'update-kotlin-lsp.sh'), '--interactive'],
                                    input='y\n', env=env, text=True, capture_output=True, timeout=15)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue(in_use.exists(), f'in-use build pruned with KOTLIN_LSP_HOME={home}')

    def test_prune_keeps_build_used_through_symlinked_path(self):
        # The reverse: DEST is the real dir, the server was started through a
        # symlink to it; its build was deleted (the ps line never contained the
        # resolved DEST).
        link = self.root / 'homelink'
        link.symlink_to(self.dest)
        in_use = link / f'kotlin-server-{self.vsx}' / 'bin' / 'intellij-server'
        self.fake_ps(f'echo "{in_use} --stdio"\n')
        result = self.run_update()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.dest / f'kotlin-server-{self.vsx}').is_dir(), 'build in use via a symlinked path was pruned')
        self.assertIn('a running server uses it', result.stderr)

    def test_no_offer_when_open_vsx_build_is_already_current(self):
        # After an earlier fallback the Open VSX build is current: no second
        # "Download and validate" prompt, just UP-TO-DATE.
        self.server(self.github, 'expired')
        self.stage_download(self.github)
        (self.dest / 'current').unlink()
        (self.dest / 'current').symlink_to(self.dest / f'kotlin-server-{self.vsx}')
        result = self.run_update('n')
        self.assertNotIn('CONFIRM-OPEN-VSX', result.stdout)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(result.stdout.endswith(f'UP-TO-DATE kotlin-server-{self.vsx}\n'), result.stdout)
        self.assert_current(self.vsx)

    def test_expired_github_build_is_not_downloaded_again(self):
        # The first run downloads and probes the expired GitHub build; the next
        # one must not fetch that archive again.
        self.server(self.github, 'expired')
        self.stage_download(self.github)
        (self.dest / 'current').unlink()
        (self.dest / 'current').symlink_to(self.dest / f'kotlin-server-{self.vsx}')
        self.run_update('n')
        calls = self.root / 'calls'
        calls.write_text('')
        result = self.run_update('n')
        self.assertEqual(result.returncode, 0, result.stderr)
        fetched = calls.read_text()
        self.assertNotIn(f'kotlin-server-{self.github}', fetched, 'the expired GitHub archive was downloaded again')
        self.assertIn('not downloading it again', result.stdout)

    def test_no_prune_without_process_list(self):
        self.fake_ps('exit 1\n')
        result = self.run_update()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('could not list running processes', result.stderr)
        self.assertTrue((self.dest / f'kotlin-server-{self.vsx}').exists(), 'pruned without a process list')

    def test_no_prune_while_a_server_runs_through_current(self):
        # A server started via the `current` symlink: which build it runs
        # cannot be told, so nothing is pruned.
        self.fake_ps(f'echo "{self.dest.resolve()}/current/bin/intellij-server --stdio"\n')
        result = self.run_update()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("launched through 'current'", result.stderr)
        self.assertTrue((self.dest / f'kotlin-server-{self.vsx}').exists())

    def test_failed_activation_without_previous_leaves_none(self):
        # No previous link before the update, and ONLY the `current` swap fails
        # (a python3 wrapper fails atomic_link's call for "current"): the
        # previous link created just before must be removed again, or it would
        # point at the still-current build and rollback would refuse.
        self.stage_download()
        real_python = shutil.which('python3')
        wrapper = self.bin / 'python3'
        wrapper.write_text('#!/bin/sh\n'
                           'if [ "$1" = "-" ] && [ "$3" = "current" ]; then echo "injected failure" >&2; exit 1; fi\n'
                           f'exec "{real_python}" "$@"\n')
        wrapper.chmod(0o755)
        result = self.run_update()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Could not activate', result.stderr)
        self.assert_current(self.old)
        self.assertFalse(os.path.lexists(self.dest / 'previous'), 'a failed activation left a previous link')

    def test_prune_skips_while_a_server_runs_through_any_current_path(self):
        # Started through an unresolved (e.g. symlinked-home) path to current.
        self.fake_ps('echo "/Users/someone/link-to-home/.local/share/kotlin-lsp/current/bin/intellij-server --stdio"\n')
        result = self.run_update()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("launched through 'current'", result.stderr)
        self.assertTrue((self.dest / f'kotlin-server-{self.vsx}').exists())

    def test_failed_activation_changes_nothing(self):
        # current cannot be replaced (a real directory in its place): the update
        # must fail without having touched previous.
        (self.dest / 'previous').symlink_to(self.dest / f'kotlin-server-{self.vsx}')
        (self.dest / 'current').unlink()
        (self.dest / 'current').mkdir()
        (self.dest / 'current' / 'keep').write_text('x')
        self.stage_download()
        result = self.run_update()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('cannot update', result.stderr)
        self.assertNotIn('Traceback', result.stderr)
        self.assert_previous(self.vsx)

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
