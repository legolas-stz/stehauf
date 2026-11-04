#!/bin/sh
# Installiert oder aktualisiert Stehauf mit einem Befehl:
# curl -fsSL https://raw.githubusercontent.com/legolas-stz/stehauf/main/get.sh | sh
#
# Alles steckt in main(), damit ein abgebrochener Download nichts halb ausführt.

main() {
  set -e
  url=https://github.com/legolas-stz/stehauf/releases/latest/download/Stehauf.zip

  case $(defaults read -g AppleLanguages 2>/dev/null | sed -n 2p) in
    *de*) loading="Lade Stehauf …"; done_msg="Stehauf ist installiert und sitzt oben rechts in der Menüleiste." ;;
    *)    loading="Downloading Stehauf …"; done_msg="Stehauf is installed and sits at the top right of the menu bar." ;;
  esac

  # Ein Update bleibt, wo die App schon liegt, sonst Programme bzw. ohne Adminrechte ~/Programme
  if [ -d "$HOME/Applications/Stehauf.app" ] && [ ! -d /Applications/Stehauf.app ]; then
    dir="$HOME/Applications"
  elif [ -w /Applications ]; then
    dir=/Applications
  else
    dir="$HOME/Applications"
  fi

  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT

  echo "$loading"
  curl -fsSL "$url" -o "$tmp/Stehauf.zip"
  ditto -xk "$tmp/Stehauf.zip" "$tmp"

  # Beim Update läuft die alte Version noch
  if pkill -x Stehauf 2>/dev/null; then
    while pgrep -x Stehauf >/dev/null; do sleep 0.2; done
  fi

  mkdir -p "$dir"
  rm -rf "$dir/Stehauf.app"
  ditto "$tmp/Stehauf.app" "$dir/Stehauf.app"
  open "$dir/Stehauf.app"
  echo "$done_msg"
}

main
