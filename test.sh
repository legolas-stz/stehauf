#!/bin/zsh
set -e
cd "$(dirname "$0")"
./build.sh
# Mit Sprachcode zeigt der Hinweis diese Sprache: ./test.sh en
args=(--test)
[[ -n $1 ]] && args+=(-AppleLanguages "($1)")
build/Stehauf.app/Contents/MacOS/Stehauf $args
