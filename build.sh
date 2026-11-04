#!/bin/zsh
# Baut build/Stehauf.app für Apple Silicon und Intel: ./build.sh [Version]
# Ohne SIGN_ID ad-hoc signiert, mit SIGN_ID="Developer ID Application: …" notarisierbar.
set -e
cd "$(dirname "$0")"
VERSION=${1:-1.0}
MIN_MACOS=14.4
APP=build/Stehauf.app

rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

for ARCH in arm64 x86_64; do
  swiftc -O -target "$ARCH-apple-macos$MIN_MACOS" main.swift -o "build/Stehauf-$ARCH"
done
lipo -create build/Stehauf-arm64 build/Stehauf-x86_64 -output "$APP/Contents/MacOS/Stehauf"

swiftc icon.swift -o build/icon
build/icon build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>io.github.legolas-stz.stehauf</string>
  <key>CFBundleName</key><string>Stehauf</string>
  <key>CFBundleExecutable</key><string>Stehauf</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleLocalizations</key><array><string>en</string><string>de</string></array>
  <key>LSMinimumSystemVersion</key><string>$MIN_MACOS</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PL

if [[ -n $SIGN_ID ]]; then
  codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$APP"
else
  codesign --force --options runtime --sign - "$APP"
fi
echo "Gebaut: $APP"
