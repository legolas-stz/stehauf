#!/bin/zsh
# Baut Stehauf aus dem Quellcode und installiert es in den Programme-Ordner.
set -e
cd "$(dirname "$0")"

./build.sh

pkill -x Stehauf || true
rm -rf /Applications/Stehauf.app
ditto build/Stehauf.app /Applications/Stehauf.app
open /Applications/Stehauf.app
echo "Installiert."
