#!/bin/zsh
LABEL=io.github.legolas-stz.stehauf
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist" "$HOME/.local/bin/stehauf"
echo "Entfernt."
