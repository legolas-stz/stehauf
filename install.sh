#!/bin/zsh
# Kompiliert und installiert Stehauf als LaunchAgent (startet bei jedem Login).
set -e
cd "$(dirname "$0")"
LABEL=io.github.legolas-stz.stehauf
BIN="$HOME/.local/bin/stehauf"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
INTERVAL_MIN=${INTERVAL_MIN:-55}
BREAK_MIN=${BREAK_MIN:-5}
IDLE_RESET_MIN=${IDLE_RESET_MIN:-20}

mkdir -p "$HOME/.local/bin" "$HOME/Library/LaunchAgents"
swiftc -O main.swift -o "$BIN"

cat > "$PLIST" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>$BIN</string></array>
  <key>EnvironmentVariables</key><dict>
    <key>INTERVAL_MIN</key><string>$INTERVAL_MIN</string>
    <key>BREAK_MIN</key><string>$BREAK_MIN</string>
    <key>IDLE_RESET_MIN</key><string>$IDLE_RESET_MIN</string>
  </dict>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ProcessType</key><string>Adaptive</string>
  <key>LowPriorityIO</key><true/>
  <key>Nice</key><integer>10</integer>
</dict></plist>
PL

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "Installiert: Erinnerung nach $INTERVAL_MIN Min. am Mac (Pause: $BREAK_MIN Min. gesperrt/schlafend oder $IDLE_RESET_MIN Min. ohne Eingabe, nicht während Meetings)."
