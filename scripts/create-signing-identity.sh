#!/bin/bash
# Create the stable self-signed identity that signs every Calamo release.
#
# TCC identifies an app by bundle ID + designated requirement (DR). Ad-hoc
# DRs are cdhash-based and change on every build — Accessibility grants die
# on each update. This certificate anchors the DR, so grants survive.
#
# CSSMERR_TP_NOT_TRUSTED in `security find-identity -v` is expected:
# codesign signs anyway, and TCC compares hashes, not trust.
#
# Create once, keep forever: a new certificate = new DR = every user
# re-grants. Back up $SECRETS_DIR — anyone holding key.pem can sign apps
# that inherit Calamo's TCC grants.
set -euo pipefail

IDENTITY="Calamo Release Signing"
KEYCHAIN="$HOME/Library/Keychains/calamo-signing.keychain-db"
KEYCHAIN_PASSWORD="$(openssl rand -base64 24)"
SECRETS_DIR="$HOME/.calamo-signing"

if [ -f "$KEYCHAIN" ]; then
  echo "error: $KEYCHAIN already exists." >&2
  echo "The signing identity must be created once and kept forever." >&2
  echo "To really start over: security delete-keychain \"$KEYCHAIN\"" >&2
  exit 1
fi

mkdir -p "$SECRETS_DIR"
chmod 700 "$SECRETS_DIR"
if [ -f "$SECRETS_DIR/key.pem" ] && [ -f "$SECRETS_DIR/cert.pem" ]; then
  echo "== 1/4 reusing existing identity from $SECRETS_DIR (same DR) =="
elif [ -f "$SECRETS_DIR/key.pem" ] || [ -f "$SECRETS_DIR/cert.pem" ]; then
  echo "error: $SECRETS_DIR holds only one of key.pem/cert.pem." >&2
  echo "Restore the pair from backup — regenerating either one changes the" >&2
  echo "DR and loses every user's TCC grants on the next update." >&2
  exit 1
else
  echo "== 1/4 generate self-signed certificate (10 years, codeSigning EKU) =="
  # openssl's progress noise goes to stderr; show it only on failure.
  if ! openssl_output=$(openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 \
    -nodes -keyout "$SECRETS_DIR/key.pem" -out "$SECRETS_DIR/cert.pem" \
    -subj "/CN=$IDENTITY/O=Calamo" \
    -addext "basicConstraints=critical,CA:false" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=critical,codeSigning" 2>&1); then
    printf '%s\n' "$openssl_output" >&2
    exit 1
  fi
fi
chmod 600 "$SECRETS_DIR/key.pem"

echo "== 2/4 create dedicated keychain =="
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security set-keychain-settings "$KEYCHAIN"   # never auto-lock
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"

echo '== 3/4 import identity (PEM: OpenSSL 3 p12 defaults break security import) =='
security import "$SECRETS_DIR/key.pem" -k "$KEYCHAIN" -T /usr/bin/codesign
security import "$SECRETS_DIR/cert.pem" -k "$KEYCHAIN"
# Let Apple tools use the key without a GUI unlock prompt.
security set-key-partition-list -S apple-tool:,apple: -s \
  -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" >/dev/null

echo "== 4/4 add keychain to the user search list =="
declare -a search_list=()
while IFS= read -r line; do
  line="${line#"${line%%[![:space:]]*}"}"   # trim leading spaces
  line="${line%\"}"; line="${line#\"}"      # strip quotes
  search_list+=("$line")
done < <(security list-keychains -d user)
# ${arr[@]+…}: expanding an empty array trips `set -u` on macOS bash 3.2.
security list-keychains -d user -s ${search_list[@]+"${search_list[@]}"} "$KEYCHAIN"

echo
echo "Identity created:"
security find-identity -p codesigning "$KEYCHAIN" | grep -F "$IDENTITY"
echo
echo "Sign with:   codesign --force --sign \"$IDENTITY\" <app>"
echo "Keychain pw: $KEYCHAIN_PASSWORD"
echo "             (store it — unlocks the keychain after a reboot; if lost, delete"
echo "             the keychain and re-run: the $SECRETS_DIR backup rebuilds it)"
echo "Back up:     $SECRETS_DIR (private key — keep it secret, keep it safe)"
echo "Remove all:  security delete-keychain \"$KEYCHAIN\"; rm -rf \"$SECRETS_DIR\""
