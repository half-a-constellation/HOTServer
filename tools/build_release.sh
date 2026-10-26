#!/usr/bin/env bash
# Builds the plugin, makes the release folders for github and thunderstore
set -euo pipefail
ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
VERSION="$(sed -n 's/.*"version_number": *"\([^"]*\)".*/\1/p' "$ROOT/manifest.json")"
DLL="$ROOT/src/bin/Release/netstandard2.1/HOTServer.dll"
OUT="$ROOT/release"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

dotnet build "$ROOT/src" -c Release
mkdir -p "$OUT"
rm -f "$OUT"/*_v"$VERSION".zip

mkdir -p "$TMP/HOTServer" && cp "$DLL" "$TMP/HOTServer/"
(cd "$TMP" && zip -qr "$OUT/HOTServer-dll_v$VERSION.zip" HOTServer)
(cd "$ROOT" && zip -qr "$OUT/HOTServer-Scripts_v$VERSION.zip" scripts linux_run.sh windows_run.cmd)
zip -qj "$OUT/HOTServer-Thunderstore_v$VERSION.zip" "$ROOT/manifest.json" "$ROOT/icon.png" "$ROOT/README.md" "$ROOT/CHANGELOG.md" "$DLL"

echo "Release $VERSION:"
for z in "$OUT"/*_v"$VERSION".zip; do echo; unzip -l "$z"; done
