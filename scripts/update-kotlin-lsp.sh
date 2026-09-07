#!/usr/bin/env bash
#
# Update the self-managed kotlin-lsp build to the latest JetBrains ships.
#
# Why this exists: intellij-server (the binary behind kotlin-lsp) is a time-bombed
# EAP build that expires ~30 days after release. JetBrains' sanctioned free path is
# to keep pulling fresh builds ("each build renews the evaluation period"). Their
# GitHub releases and the Mason registry both lag by weeks, so the current build is
# discovered from the Open VSX `kotlin-server` extension's server-bundle.json — the
# same trail documented in the readme's Troubleshooting section and
# docs/design-decisions.md.
#
# Idempotent: exits 0 early ("UP-TO-DATE ...") when the installed build already
# matches the latest. Safe to run while nvim is open — it never launches the server
# (which holds a machine-wide analyzer lock); it only downloads and repoints the
# `current` symlink, which takes effect on the next server start. The last stdout
# line is a machine-readable status: "UP-TO-DATE kotlin-server-<build>" or
# "UPDATED kotlin-server-<build>".
set -euo pipefail

DEST="${KOTLIN_LSP_HOME:-$HOME/.local/share/kotlin-lsp}"
API="https://open-vsx.org/api/JetBrains/kotlin-server"

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

# Latest extension version.
ext_json="$(curl -fsSL "$API")"
ext_ver="$(jq_field "$ext_json" version)"
[ -n "$ext_ver" ] || { echo "could not determine latest extension version" >&2; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# server-bundle.json inside that version's platform .vsix names the server build.
vsix_url="$API/$target/$ext_ver/file/JetBrains.kotlin-server-$ext_ver@$target.vsix"
curl -fsSL "$vsix_url" -o "$tmp/ext.vsix"
bundle="$(unzip -p "$tmp/ext.vsix" extension/server-bundle.json)"
build="$(jq_field "$bundle" version)"
url="$(jq_field "$bundle" url)"
sha256="$(jq_field "$bundle" sha256)"
archive="$(jq_field "$bundle" archiveName)"
[ -n "$build" ] && [ -n "$url" ] && [ -n "$sha256" ] || { echo "server-bundle.json missing fields" >&2; exit 1; }

# Already current?
have=""
[ -L "$DEST/current" ] && have="$(basename "$(readlink "$DEST/current")")"
if [ "$have" = "kotlin-server-$build" ]; then
    echo "UP-TO-DATE kotlin-server-$build"
    exit 0
fi
echo "updating: ${have:-<none>} -> kotlin-server-$build (extension $ext_ver)"

# Download + verify. --progress-bar writes "###  42.1%" to stderr; the :KotlinLspUpdate
# command streams that to a fidget progress bar (harmless noise in a manual run).
echo "· downloading $archive"
curl -fL --progress-bar "$url" -o "$tmp/$archive"
echo "· verifying checksum"
if command -v shasum >/dev/null 2>&1; then
    calc="$(shasum -a 256 "$tmp/$archive" | awk '{print $1}')"
else
    calc="$(sha256sum "$tmp/$archive" | awk '{print $1}')"
fi
if [ "$calc" != "$sha256" ]; then
    echo "sha256 MISMATCH for $archive: got $calc want $sha256" >&2
    exit 1
fi

# Extract (.sit is a zip; linux ships .tar.gz). The archive root is
# kotlin-server-<build>/.
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

# Install + repoint the symlink atomically.
mkdir -p "$DEST"
rm -rf "$DEST/kotlin-server-$build"
mv "$src" "$DEST/kotlin-server-$build"
ln -sfn "$DEST/kotlin-server-$build" "$DEST/current"

# Prune older builds to reclaim disk (each is ~1 GB extracted); keep only current.
for d in "$DEST"/kotlin-server-*; do
    [ -d "$d" ] || continue
    [ "$d" = "$DEST/kotlin-server-$build" ] && continue
    rm -rf "$d"
done

echo "UPDATED kotlin-server-$build"
