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

CERTS="$(mktemp -d)"
FRESH_HOME="$(mktemp -d)"
cleanup() {
  rm -rf "$CERTS" "$FRESH_HOME"
  if [ -d "$ROOT/app/.build.masked" ]; then
    mv "$ROOT/app/.build.masked" "$ROOT/app/.build"
  fi
}
trap cleanup EXIT

BUILD_NUMBER="$(git -C "$ROOT" rev-list --count HEAD)"
echo "== 1/4 stamp version $VERSION ($BUILD_NUMBER) =="
plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$APP/Contents/Info.plist"

echo "== 2/4 sign with the stable identity =="
codesign --force --sign "Calamo Release Signing" "$APP"
# The shipped leaf certificate must be byte-identical to the stable pair:
# any other identity of the same name would silently anchor a new DR.
codesign --display "--extract-certificates=$CERTS/leaf" "$APP"
openssl x509 -in "$CERT_PEM" -outform DER -out "$CERTS/expected.der"
cmp -s "$CERTS/leaf0" "$CERTS/expected.der" \
  || { echo "error: app signed with a different certificate than $CERT_PEM" >&2; exit 1; }
codesign --verify --strict "$APP"

echo "== 3/4 launch check =="
# The build tree hosts Bundle.module's baked fallback and would mask a
# broken resource lookup — hide it, as on user machines. Fresh HOME =
# first-launch state, so the check flashes the wizard for a few seconds.
[ ! -d "$ROOT/app/.build" ] || mv "$ROOT/app/.build" "$ROOT/app/.build.masked"
HOME="$FRESH_HOME" "$APP/Contents/MacOS/Calamo" & APP_PID=$!
sleep 4
kill "$APP_PID" 2>/dev/null \
  || { echo "error: the packaged app dies at launch" >&2; exit 1; }
[ ! -d "$ROOT/app/.build.masked" ] || mv "$ROOT/app/.build.masked" "$ROOT/app/.build"

echo "== 4/4 dmgbuild =="
tiffutil -cathidpicheck "$ROOT/assets/dmg-background.png" \
  "$ROOT/assets/dmg-background@2x.png" -out "$ROOT/build/dmg-background.tiff"
dmgbuild -s "$ROOT/scripts/dmg-settings.py" -D "app=$APP" \
  -D "background=$ROOT/build/dmg-background.tiff" Calamo "$DMG"
shasum -a 256 "$DMG"
