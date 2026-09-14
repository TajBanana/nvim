#!/usr/bin/env python3
"""Release metadata and isolated LSP startup checks for update-kotlin-lsp.sh."""
import json
import fcntl
import os
from pathlib import Path
import re
import selectors
import signal
import subprocess
import sys
import tempfile
import time
from urllib.parse import urlparse


def github_bundle(release, target):
    tag = release['tag_name']
    if not re.fullmatch(r'kotlin-lsp/v\d+\.\d+\.\d+', tag):
        raise ValueError(f'Unexpected GitHub release tag: {tag}')
    build = tag.split('/v')[1]
    suffix = {'darwin-arm64': '-aarch64.sit', 'darwin-x64': '.sit',
              'linux-arm64': '-aarch64.tar.gz', 'linux-x64': '.tar.gz'}[target]
    archive = f'kotlin-server-{build}{suffix}'
    # Use published links, including releases whose archives are linked in the
    # release notes rather than uploaded as GitHub assets.
    urls = re.findall(r'https://[^\s)<>]+', release.get('body', ''))
    urls += [asset['browser_download_url'] for asset in release.get('assets', [])]
    def find(name):
        for url in urls:
            parsed = urlparse(url)
            if parsed.hostname in {'download.jetbrains.com', 'download-cdn.jetbrains.com', 'github.com'} and Path(parsed.path).name == name:
                return url
        raise ValueError(f'GitHub release has no published link for {name}')
    return {'version': build, 'archiveName': archive, 'url': find(archive),
            'checksumUrl': find(archive + '.sha256')}


def probe(launcher, timeout=45):
    """Return 0 for initialize success, 10 for explicit expiry, 1 otherwise.

    Never infer expiry from age, a timeout, or a generic startup failure. Keep
    stdin open until the response: EOF cancels initialization in this server.
    """
    with tempfile.TemporaryDirectory(prefix='kotlin-lsp-probe-') as tmp:
        env = os.environ.copy()
        # Do not inherit JVM options pointing at the user's active cache/logs.
        env['IJ_JAVA_OPTIONS'] = ' '.join(
            f'-Didea.{key}.path={tmp}/{key}' for key in ('config', 'system', 'log'))
        process = subprocess.Popen(
            [str(Path(launcher).resolve()), '--stdio', f'--system-path={tmp}/system'],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            env=env, start_new_session=True)
        transcript = bytearray()
        pending = bytearray()
        try:
            message = json.dumps({'jsonrpc': '2.0', 'id': 1, 'method': 'initialize',
                                  'params': {'processId': None, 'rootUri': None,
                                             'workspaceFolders': [], 'capabilities': {}}}).encode()
            process.stdin.write(f'Content-Length: {len(message)}\r\n\r\n'.encode() + message)
            process.stdin.flush()
            with selectors.DefaultSelector() as selector:
                selector.register(process.stdout, selectors.EVENT_READ)
                selector.register(process.stderr, selectors.EVENT_READ)
                deadline = time.monotonic() + timeout
                while selector.get_map() and time.monotonic() < deadline:
                    for key, _ in selector.select(min(0.25, max(0, deadline - time.monotonic()))):
                        data = os.read(key.fileobj.fileno(), 65536)
                        if not data:
                            selector.unregister(key.fileobj)
                            continue
                        transcript.extend(data)
                        if b'intellij-server has expired' in transcript or b'kotlin-server has expired' in transcript:
                            return 10
                        if key.fileobj is not process.stdout:
                            continue
                        pending.extend(data)
                        while b'\r\n\r\n' in pending:
                            header, body = pending.split(b'\r\n\r\n', 1)
                            length = re.search(rb'Content-Length:\s*(\d+)', header, re.I)
                            if not length:
                                raise ValueError('Invalid LSP response header')
                            size = int(length[1])
                            if len(body) < size:
                                break
                            reply = json.loads(body[:size])
                            pending[:] = body[size:]
                            if reply.get('id') == 1 and ('result' in reply or 'error' in reply):
                                if isinstance(reply.get('result'), dict) and 'capabilities' in reply['result']:
                                    return 0
                                raise ValueError('Server rejected initialize')
            raise ValueError('Server exited or timed out before initialize completed')
        except (OSError, ValueError) as error:
            print(f'Cannot verify build expiry: {error}', file=sys.stderr)
            print(transcript.decode(errors='replace')[-2000:], file=sys.stderr)
            return 1
        finally:
            # Kill only the isolated probe and any children it created.
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
            for stream in (process.stdin, process.stdout, process.stderr):
                stream.close()


if __name__ == '__main__':
    try:
        if sys.argv[1] == 'locked':
            destination = Path(sys.argv[2])
            destination.mkdir(parents=True, exist_ok=True)
            lock = os.open(destination / '.update.lock', os.O_CREAT | os.O_RDWR, 0o600)
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                print('Another Kotlin LSP update is already running or awaiting confirmation.', file=sys.stderr)
                sys.exit(75)
            os.set_inheritable(lock, True)
            os.execvp('bash', ['bash', sys.argv[3], '--locked', *sys.argv[4:]])
        elif sys.argv[1] == 'github':
            print(json.dumps(github_bundle(json.load(sys.stdin), sys.argv[2])))
        elif sys.argv[1] == 'probe':
            sys.exit(probe(sys.argv[2]))
        else:
            raise ValueError('Expected github or probe')
    except (ValueError, KeyError, OSError) as error:
        sys.exit(str(error))
