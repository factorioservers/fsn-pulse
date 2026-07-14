#!/usr/bin/env bash
# Build the mod-portal-ready zip: dist/fsn-pulse_<version>.zip
#
# The Factorio mod portal requires the zip file to be named
# {mod-name}_{version}.zip; we also name the inner folder the same way,
# which is the conventional layout the game itself uses.
set -euo pipefail

cd "$(dirname "$0")/.."

NAME=$(python3 -c 'import json; print(json.load(open("info.json"))["name"])')
VERSION=$(python3 -c 'import json; print(json.load(open("info.json"))["version"])')
PKG="${NAME}_${VERSION}"

rm -rf "build/${PKG}" "dist/${PKG}.zip"
mkdir -p "build/${PKG}" dist

cp info.json control.lua changelog.txt LICENSE README.md "build/${PKG}/"

(cd build && zip -r -X "../dist/${PKG}.zip" "${PKG}")

echo "Built dist/${PKG}.zip:"
unzip -l "dist/${PKG}.zip"
