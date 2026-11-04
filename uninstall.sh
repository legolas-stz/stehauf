#!/bin/zsh
pkill -x Stehauf
rm -rf /Applications/Stehauf.app "$HOME/Applications/Stehauf.app"
defaults delete io.github.legolas-stz.stehauf 2>/dev/null
echo "Entfernt."
