#!/bin/zsh
# Veröffentlicht Stehauf.zip als GitHub-Release: ./release.sh 1.0
# Notarisiert, wenn SIGN_ID und NOTARY_PROFILE (xcrun notarytool store-credentials) gesetzt sind.
set -e
cd "$(dirname "$0")"
VERSION=$1
[[ -n $VERSION ]] || { echo "Aufruf: ./release.sh 1.0"; exit 1 }

./build.sh "$VERSION"
if [[ -n $NOTARY_PROFILE ]]; then
  ditto -c -k --keepParent build/Stehauf.app build/notarize.zip
  xcrun notarytool submit build/notarize.zip --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple build/Stehauf.app
fi
ditto -c -k --keepParent build/Stehauf.app build/Stehauf.zip
gh release create "v$VERSION" build/Stehauf.zip --target "$(git rev-parse HEAD)" --title "Stehauf $VERSION" --generate-notes
