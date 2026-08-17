#!/bin/bash
# Never ad-hoc: TCC keys grants to the signature's designated requirement —
# an unstable one loses every user's Accessibility grant at the next update
# (docs/distribution.md).
set -euo pipefail

VERSION="${1:?usage: package.sh <version>  (e.g. 1.0.0)}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/Calamo.app"
DMG="$ROOT/build/Calamo-$VERSION.dmg"
CERT_PEM="$HOME/.calamo-signing/cert.pem"

[ -d "$APP" ] || { echo "error: $APP missing — run ./build.sh first" >&2; exit 1; }
[ -f "$CERT_PEM" ] || { echo "error: $CERT_PEM missing — run scripts/create-signing-identity.sh" >&2; exit 1; }
command -v dmgbuild >/dev/null || { echo "error: dmgbuild missing — pipx install dmgbuild" >&2; exit 1; }

BUILD_NUMBER="$(git -C "$ROOT" rev-list --count HEAD)"
echo "== 1/3 stamp version $VERSION ($BUILD_NUMBER) =="
plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$APP/Contents/Info.plist"

echo "== 2/3 sign with the stable identity =="
codesign --force --sign "Calamo Release Signing" "$APP"
# The shipped leaf certificate must be byte-identical to the stable pair:
# any other identity of the same name would silently anchor a new DR.
CERTS="$(mktemp -d)"
trap 'rm -rf "$CERTS"' EXIT
codesign --display "--extract-certificates=$CERTS/leaf" "$APP"
openssl x509 -in "$CERT_PEM" -outform DER -out "$CERTS/expected.der"
cmp -s "$CERTS/leaf0" "$CERTS/expected.der" \
  || { echo "error: app signed with a different certificate than $CERT_PEM" >&2; exit 1; }
codesign --verify --strict "$APP"

echo "== 3/3 dmgbuild =="
tiffutil -cathidpicheck "$ROOT/assets/dmg-background.png" \
  "$ROOT/assets/dmg-background@2x.png" -out "$ROOT/build/dmg-background.tiff"
dmgbuild -s "$ROOT/scripts/dmg-settings.py" -D "app=$APP" \
  -D "background=$ROOT/build/dmg-background.tiff" Calamo "$DMG"
shasum -a 256 "$DMG"
