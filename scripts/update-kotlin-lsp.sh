#!/usr/bin/env bash
#
# Update the self-managed kotlin-lsp build to the latest JetBrains ships.
#
# Prefer the latest GitHub release. Only an explicit expiry response from an
# isolated startup probe permits offering Open VSX, with a second confirmation. Download, checksum,
# timeout, and other startup failures leave the installed version untouched.
# The probe uses temporary cache/config/log paths and never opens a project.
# Last stdout line: "UP-TO-DATE kotlin-server-<build>" or "UPDATED ...".
set -euo pipefail
locked=false
if [ "${1:-}" = --locked ]; then
    locked=true
    shift
fi
mode="${1:-update}"
case "$mode" in
    update | --preview | --interactive) ;;
    *) echo "usage: $0 [--preview | --interactive]" >&2; exit 1 ;;
esac

DEST="${KOTLIN_LSP_HOME:-$HOME/.local/share/kotlin-lsp}"
API="https://open-vsx.org/api/JetBrains/kotlin-server"
GITHUB_API="https://api.github.com/repos/Kotlin/kotlin-lsp/releases/latest"
HELPER="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/kotlin-lsp-release.py"

# The OS releases this lock even after a crash. It remains held while waiting
# for the Open VSX confirmation, including across different Neovim instances.
if [ "$mode" != --preview ] && [ "$locked" = false ]; then
    exec python3 "$HELPER" locked "$DEST" "${BASH_SOURCE[0]}" "$mode"
fi

# Platform -> Open VSX extension target. The per-platform .vsix carries a
# server-bundle.json with the matching .sit/.tar.gz URL + sha256, so we never
# reconstruct download URLs ourselves.
os="$(uname -s)"
arch="$(uname -m)"
case "$os/$arch" in
    Darwin/arm64)               target="darwin-arm64" ;;
    Darwin/x86_64)              target="darwin-x64" ;;
    Linux/x86_64)               target="linux-x64" ;;
    Linux/aarch64 | Linux/arm64) target="linux-arm64" ;;
    *) echo "unsupported platform: $os/$arch" >&2; exit 1 ;;
esac

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing required tool: $1" >&2; exit 1; }; }
need curl
need python3
need unzip

jq_field() { printf '%s' "$1" | python3 -c "import sys,json;print(json.load(sys.stdin)[\"$2\"])"; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
have=""
[ -L "$DEST/current" ] && have="$(basename "$(readlink "$DEST/current")")"

prepare_candidate() {
    build="$(jq_field "$bundle" version)"
    url="$(jq_field "$bundle" url)"
    archive="$(jq_field "$bundle" archiveName)"
    # These fields become paths below: reject malformed remote metadata.
    [[ "$build" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "invalid build: $build" >&2; exit 1; }
    [[ "$archive" != */* && "$archive" == kotlin-server-* ]] || { echo "invalid archive name" >&2; exit 1; }
    src="$DEST/kotlin-server-$build"
    if [ -x "$src/bin/intellij-server" ]; then
        return
    fi
    if [ "$source" = GitHub ]; then
        checksum_url="$(jq_field "$bundle" checksumUrl)"
        checksum="$(curl -fsSL "$checksum_url")"
        sha256="$(printf '%s' "$checksum" | awk '{print $1; exit}')"
    else
        sha256="$(jq_field "$bundle" sha256)"
    fi
    [[ "$sha256" =~ ^[a-fA-F0-9]{64}$ ]] || { echo "invalid SHA-256 checksum" >&2; exit 1; }
    echo "· downloading $archive ($source)"
    curl -fL --progress-bar "$url" -o "$tmp/$archive"
    echo "· verifying checksum"
    calc="$(python3 - "$tmp/$archive" <<'HASH'
import hashlib, sys
h = hashlib.sha256()
with open(sys.argv[1], 'rb') as stream:
    for chunk in iter(lambda: stream.read(1024 * 1024), b''):
        h.update(chunk)
print(h.hexdigest())
HASH
)"
    [ "$calc" = "$sha256" ] || { echo "sha256 MISMATCH for $archive" >&2; exit 1; }
    echo "· extracting"
    mkdir -p "$tmp/x"
    case "$archive" in
        *.tar.gz | *.tgz) tar -xzf "$tmp/$archive" -C "$tmp/x" ;;
        *.sit | *.zip)
            if command -v ditto >/dev/null 2>&1; then
                ditto -x -k "$tmp/$archive" "$tmp/x"
            else
                unzip -q "$tmp/$archive" -d "$tmp/x"
            fi
            ;;
        *) echo "unknown archive type: $archive" >&2; exit 1 ;;
    esac
    src="$tmp/x/kotlin-server-$build"
    [ -x "$src/bin/intellij-server" ] || { echo "extracted tree missing bin/intellij-server" >&2; exit 1; }
    # Record provenance only for a download made here, never guess where an
    # existing installation originally came from.
    python3 - "$src/install-source.json" "$build" "$source" "$url" <<'META'
import json, sys
with open(sys.argv[1], 'w') as stream:
    json.dump(dict(version=sys.argv[2], source=sys.argv[3], url=sys.argv[4]), stream)
META
}

check_candidate() {
    echo "· checking $source build $build for expiry"
    probe_status=0
    python3 "$HELPER" probe "$src/bin/intellij-server" || probe_status=$?
    if [ "$probe_status" -ne 0 ] && [ "$probe_status" -ne 10 ]; then
        echo "Could not validate $source build $build; keeping current installation." >&2
        exit 1
    fi
}

source=GitHub
echo "· checking latest GitHub release"
release="$(curl -fsSL --connect-timeout 10 --max-time 30 "$GITHUB_API")"
bundle="$(printf '%s' "$release" | python3 "$HELPER" github "$target")"
if [ "$mode" = --preview ]; then
    # Metadata only: the popup must not claim this candidate has passed its
    # expiry check, or download/start a server before the user chooses update.
    echo "CANDIDATE kotlin-server-$(jq_field "$bundle" version) GitHub"
    exit 0
fi
prepare_candidate
check_candidate
if [ "$probe_status" -eq 10 ]; then
    github_build="$build"
    echo "GitHub build $build has expired; checking Open VSX."
    source="Open VSX"
    ext_json="$(curl -fsSL "$API")"
    ext_ver="$(jq_field "$ext_json" version)"
    [[ "$ext_ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "invalid extension version" >&2; exit 1; }
    vsix_url="$API/$target/$ext_ver/file/JetBrains.kotlin-server-$ext_ver@$target.vsix"
    curl -fsSL "$vsix_url" -o "$tmp/ext.vsix"
    bundle="$(unzip -p "$tmp/ext.vsix" extension/server-bundle.json)"
    if [ "$(jq_field "$bundle" version)" = "$github_build" ]; then
        echo "Open VSX offers the same expired build; keeping current installation." >&2
        exit 12
    fi
    fallback_build="$(jq_field "$bundle" version)"
    [[ "$fallback_build" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "invalid fallback build" >&2; exit 1; }
    # Only extension metadata has been fetched so far, not the server archive.
    # Keep this exact bundle in memory so the confirmation approves this version.
    echo "CONFIRM-OPEN-VSX $github_build $fallback_build"
    if [ "$mode" != --interactive ] && [ ! -t 0 ]; then
        echo "Open VSX requires confirmation; run in a terminal or use :KotlinLspUpdate." >&2
        exit 20
    fi
    if [ "$mode" != --interactive ]; then
        echo "GitHub $github_build expired. Download Open VSX $fallback_build? [y/N]"
    fi
    answer=""
    read -r answer || true
    case "$answer" in
        y | Y) ;;
        *) echo "CANCELLED"; exit 20 ;;
    esac
    prepare_candidate
    check_candidate
    if [ "$probe_status" -eq 10 ]; then
        echo "Open VSX build $build has also expired; keeping current installation." >&2
        exit 11
    fi
fi

if [ "$have" = "kotlin-server-$build" ] && [ "$src" = "$DEST/kotlin-server-$build" ]; then
    echo "UP-TO-DATE kotlin-server-$build"
    exit 0
fi
echo "installing $source build $build"

# Install + repoint the symlink atomically.
mkdir -p "$DEST"
if [ "$src" != "$DEST/kotlin-server-$build" ]; then
    rm -rf "$DEST/kotlin-server-$build"
    mv "$src" "$DEST/kotlin-server-$build"
fi
python3 - "$DEST" "$build" <<'LINK'
import os, sys, uuid
from pathlib import Path
dest = Path(sys.argv[1]).resolve()
link = dest / ('.current-' + uuid.uuid4().hex)
try:
    link.symlink_to(dest / ('kotlin-server-' + sys.argv[2]))
    os.replace(link, dest / 'current')
finally:
    link.unlink(missing_ok=True)
LINK

# Prune older builds to reclaim disk (each is ~1 GB extracted); keep only current.
for d in "$DEST"/kotlin-server-*; do
    [ -d "$d" ] || continue
    [ "$d" = "$DEST/kotlin-server-$build" ] && continue
    rm -rf "$d" || echo "Warning: could not remove old build $d" >&2
done

echo "UPDATED kotlin-server-$build"
