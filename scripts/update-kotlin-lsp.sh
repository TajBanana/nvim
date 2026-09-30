#!/usr/bin/env bash
#
# Update the self-managed kotlin-lsp build to the latest JetBrains ships.
#
# Prefer the latest GitHub release. Only an explicit expiry response from an
# isolated startup probe permits offering Open VSX, with a second confirmation. Download, checksum,
# timeout, and other startup failures leave the installed version untouched.
# The probe uses temporary cache/config/log paths and never opens a project.
# Last stdout line: "UP-TO-DATE kotlin-server-<build>" or "UPDATED ...".
#
# The build that was current before an update is kept as `previous` (a symlink
# beside `current`); `rollback` swaps the two after checking the previous build
# still starts. Last stdout line: "ROLLED-BACK kotlin-server-<build>". Each link
# is replaced atomically, but the swap is two replacements: a failure between
# them restores `previous` and leaves `current` untouched.
set -euo pipefail
locked=false
if [ "${1:-}" = --locked ]; then
    locked=true
    shift
fi
mode="${1:-update}"
case "$mode" in
    update | --preview | --interactive | rollback) ;;
    *) echo "usage: $0 [--preview | --interactive | rollback]" >&2; exit 1 ;;
esac

DEST="${KOTLIN_LSP_HOME:-$HOME/.local/share/kotlin-lsp}"
# Symlink targets are written as "$DEST/<build>"; a relative DEST would make
# them relative to the link's own directory, i.e. dangling.
case "$DEST" in
    /*) ;;
    *) DEST="$PWD/$DEST" ;;
esac
# Also resolve symlinks and trailing slashes, so the prune step below
# recognises a server started from a versioned build directory by finding
# "$DEST/<build>/" in process command lines -- an unresolved DEST (behind a
# symlink, or ending in "/") never matched, so in-use builds were pruned.
if [ "$mode" != --preview ]; then
    mkdir -p "$DEST"
fi
if [ -d "$DEST" ]; then
    DEST="$(cd -P -- "$DEST" && pwd)"
fi
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
need python3
if [ "$mode" != rollback ]; then
    need curl
    need unzip
fi

jq_field() { printf '%s' "$1" | python3 -c "import sys,json;print(json.load(sys.stdin)[\"$2\"])"; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
# Where $DEST/<link> points, as an absolute path ("" when it is not a
# symlink). Used as-is: a link may point outside $DEST (a build kept
# elsewhere), and assuming "$DEST/<basename>" treated such a valid `previous`
# as dangling and deleted it.
link_target() {
    local t
    [ -L "$DEST/$1" ] || return 0
    t="$(readlink "$DEST/$1")"
    case "$t" in
        /*) ;;
        *) t="$DEST/$t" ;;
    esac
    printf '%s' "$t"
}
have_path="$(link_target current)"
have=""
[ -n "$have_path" ] && have="$(basename "$have_path")"
# For messages: `current` may be missing, or a plain directory (not a link),
# which printed an empty name ("keeping .").
have_name="${have:-the current installation}"
# Whether `current` pointed at a working build before this run.
had_working=false
[ -n "$have_path" ] && [ -x "$have_path/bin/intellij-server" ] && had_working=true

# Atomically point $DEST/<name> at <target> (symlink + rename, never a moment
# with no link). Fails with a one-line message (e.g. a read-only install dir),
# not a Python traceback.
atomic_link() {
    python3 - "$DEST" "$1" "$2" <<'LINK'
import os, sys, uuid
from pathlib import Path
dest = Path(sys.argv[1]).resolve()
tmp = dest / ('.' + sys.argv[2] + '-' + uuid.uuid4().hex)
try:
    tmp.symlink_to(Path(sys.argv[3]))
    os.replace(tmp, dest / sys.argv[2])
except OSError as err:
    print(f'cannot update {dest / sys.argv[2]}: {err.strerror}', file=sys.stderr)
    sys.exit(1)
finally:
    tmp.unlink(missing_ok=True)
LINK
}

# Swap current <-> previous. After the usual expiry-driven update the previous
# build has itself expired, and switching back to it would only produce a
# server that refuses to start -- so it must pass the same startup probe first.
if [ "$mode" = rollback ]; then
    prev_path="$(link_target previous)"
    if [ -n "$prev_path" ] && [ ! -x "$prev_path/bin/intellij-server" ]; then
        # The build it pointed at is gone: drop the dangling link.
        rm -f "$DEST/previous"
        prev_path=""
    fi
    if [ -z "$prev_path" ]; then
        echo "No previous Kotlin LSP build to roll back to." >&2
        exit 13
    fi
    prev="$(basename "$prev_path")"
    if [ -n "$have_path" ] && [ "$prev_path" -ef "$have_path" ]; then
        echo "The previous build $prev is already current; nothing to roll back to." >&2
        exit 13
    fi
    echo "· checking $prev for expiry"
    probe_status=0
    python3 "$HELPER" probe "$prev_path/bin/intellij-server" || probe_status=$?
    if [ "$probe_status" -eq 10 ]; then
        echo "Previous build $prev has expired; rolling back would not start. Keeping $have_name." >&2
        exit 14
    elif [ "$probe_status" -ne 0 ]; then
        echo "Could not validate previous build $prev; keeping $have_name." >&2
        exit 1
    fi
    # previous first: if repointing current then fails, previous is restored
    # and nothing has changed. The reverse order could leave current and
    # previous on the same build.
    if [ -n "$have_path" ] && [ -d "$have_path" ]; then
        atomic_link previous "$have_path"
    else
        rm -f "$DEST/previous"
    fi
    if ! atomic_link current "$prev_path"; then
        atomic_link previous "$prev_path" || true
        echo "Could not switch to $prev; keeping $have_name." >&2
        exit 1
    fi
    echo "ROLLED-BACK $prev"
    exit 0
fi

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
    if [ "$probe_status" -eq 10 ]; then
        remember_expired "$build"
    fi
}

# Builds that a probe found expired. The builds are time-bombed, so an expired
# one never works again: after an Open VSX fallback, every later update used to
# download the same expired GitHub archive (~500 MB) again just to probe it.
EXPIRED_LIST="$DEST/.expired-builds"
remember_expired() {
    if ! is_known_expired "$1"; then
        echo "$1" >>"$EXPIRED_LIST" 2>/dev/null || true
    fi
}
is_known_expired() {
    [ -f "$EXPIRED_LIST" ] && grep -qxF -- "$1" "$EXPIRED_LIST"
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
build="$(jq_field "$bundle" version)"
if is_known_expired "$build"; then
    echo "· GitHub build $build expired (found earlier); not downloading it again"
    probe_status=10
else
    prepare_candidate
    check_candidate
fi
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
    if is_known_expired "$fallback_build"; then
        echo "Open VSX build $fallback_build has also expired (found earlier); keeping current installation." >&2
        exit 11
    fi
    # The fallback is already the current build (an earlier fallback): nothing
    # to download or confirm -- it used to ask "Download and validate" again.
    # Still probe it: it may have expired since.
    if [ -n "$have_path" ] && [ "$have_path" -ef "$DEST/kotlin-server-$fallback_build" ]; then
        build="$fallback_build"
        src="$DEST/kotlin-server-$build"
        check_candidate
        if [ "$probe_status" -eq 10 ]; then
            echo "Open VSX build $build has also expired; keeping current installation." >&2
            exit 11
        fi
        echo "UP-TO-DATE kotlin-server-$build"
        exit 0
    fi
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

if [ -n "$have_path" ] && [ "$have_path" -ef "$DEST/kotlin-server-$build" ] && [ "$src" = "$DEST/kotlin-server-$build" ]; then
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
# Remember the build we replaced (so :KotlinLspRollback can return to it)
# BEFORE switching current: if the switch then fails, previous is restored and
# nothing changed -- the reverse order could leave current switched while the
# script reported failure ("installation preserved").
old_prev=""
[ -L "$DEST/previous" ] && old_prev="$(readlink "$DEST/previous")"
if [ -n "$have_path" ] && [ -d "$have_path" ] && ! [ "$have_path" -ef "$DEST/kotlin-server-$build" ]; then
    atomic_link previous "$have_path"
fi
if ! atomic_link current "$DEST/kotlin-server-$build"; then
    # Put previous back exactly as it was -- including REMOVING it when there
    # was none (leaving it would point at the build that is still current, and
    # rollback would then refuse with "already current").
    if [ -n "$old_prev" ]; then
        atomic_link previous "$old_prev" || true
    else
        rm -f "$DEST/previous"
    fi
    echo "Could not activate kotlin-server-$build; keeping $have_name." >&2
    exit 1
fi

# Prune older builds to reclaim disk (each is ~1 GB extracted); keep current,
# the rollback target, and any build a running server was launched from.
# Neovim launches the server through the `current` symlink (kotlin.lua), so a
# running server's build cannot be told from its command line: while ANY
# server started through a `current` path is running, nothing is pruned, and
# the old builds go on a later update. A server started from a versioned
# directory (by hand, or another tool) is recognised and kept. Fails CLOSED
# without a process list too.
# (2026-09-29: Neovim briefly launched the resolved versioned directory so this
# check could keep exactly the in-use builds; that made Neovim relaunch the OLD
# build after an update, and was reverted.)
keep_prev="$(link_target previous)"
prune=true
# -ww: never truncate command lines to the terminal width (procps honours
# COLUMNS). A plain [[ == ]] match, not `printf | grep -q`: grep exits at the
# first match, printf then dies of SIGPIPE, and with pipefail a FOUND build
# read as "not in use" and was deleted.
if ! running="$(ps -A -ww -o args= 2>/dev/null)" || [ -z "$running" ]; then
    echo "Not pruning old builds: could not list running processes." >&2
    prune=false
# Any ".../current/bin/intellij-server", not just "$DEST/current/": a server
# may have been started through an unresolved path to the same install (a
# symlinked home or KOTLIN_LSP_HOME). Broad on purpose -- the cost of a false
# match is only a postponed cleanup.
elif [[ "$running" == */current/bin/intellij-server* ]]; then
    echo "Not pruning old builds: a server launched through 'current' is running." >&2
    prune=false
# `current` was missing or dangling before this update, so no `previous` was
# recorded: which old build is the working one is unknown, and pruning could
# delete the only one that runs (it did, after a test repointed `current` at a
# build that did not exist).
elif [ "$had_working" != true ]; then
    echo "Not pruning old builds: 'current' did not point at a working build before this update." >&2
    prune=false
fi
if [ "$prune" = true ]; then
    for d in "$DEST"/kotlin-server-*; do
        [ -d "$d" ] || continue
        [ "$d" = "$DEST/kotlin-server-$build" ] && continue
        [ -n "$keep_prev" ] && [ "$d" -ef "$keep_prev" ] && continue
        # By the build's own directory name, not its full path: a server started
        # through a symlinked path to the install (an unresolved home or
        # KOTLIN_LSP_HOME) never matched the resolved $DEST, and its build was
        # deleted. A false match only postpones the cleanup.
        if [[ "$running" == *"/$(basename "$d")/bin/intellij-server"* ]]; then
            echo "Keeping $(basename "$d"): a running server uses it." >&2
            continue
        fi
        rm -rf "$d" || echo "Warning: could not remove old build $d" >&2
    done
fi

echo "UPDATED kotlin-server-$build"
