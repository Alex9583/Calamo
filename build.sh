#!/bin/bash
# Single dev/CI build chain: cargo staticlib → uniffi Swift bindings →
# XCFramework → swift build → assembled, ad-hoc-signed build/Calamo.app.
# Bindings are regenerated on every build, never committed.
set -euo pipefail
export PATH="$HOME/.cargo/bin:$PATH"

ROOT="$(cd "$(dirname "$0")" && pwd)"
CORE="$ROOT/core"
FFI_CRATE="$CORE/calamo-ffi"
TARGET=aarch64-apple-darwin
STATICLIB="$CORE/target/$TARGET/release/libcalamo_ffi.a"

# Align the min-OS of every object with the SwiftPM platform (.macOS(.v14)).
# Required once llama.cpp's CMake objects join the staticlib: they compile at
# the host OS version otherwise and ld emits hundreds of warnings. When
# changing: cargo clean -p llama-cpp-sys-2 --target aarch64-apple-darwin.
export MACOSX_DEPLOYMENT_TARGET=14.0

echo "== 1/5 cargo build --release ($TARGET, staticlib) =="
cargo build --manifest-path "$CORE/Cargo.toml" -p calamo-ffi --release --target "$TARGET"
ls -lh "$STATICLIB"

echo "== 2/5 uniffi-bindgen-swift (library mode on the .a) =="
GEN_SWIFT="$ROOT/CalamoCore/Sources/CalamoCore"
GEN_HEADERS="$ROOT/build/headers"
rm -rf "$GEN_SWIFT" "$GEN_HEADERS"
mkdir -p "$GEN_SWIFT" "$GEN_HEADERS"
# uniffi-bindgen-swift runs `cargo metadata` from the CWD, so run it from
# the crate directory.
bindgen() {
  (cd "$FFI_CRATE" && cargo run --quiet --release \
    --features bindgen-swift --bin uniffi-bindgen-swift -- "$@")
}
bindgen --swift-sources "$STATICLIB" "$GEN_SWIFT"
bindgen --headers "$STATICLIB" "$GEN_HEADERS"
# Two traps:
# - --module-name calamoFFI: the generated Swift does
#   `#if canImport(calamoFFI)`; with the default module name (`calamo`) the
#   import silently vanishes and the build fails with dozens of
#   "cannot find … in scope".
# - NO --xcframework flag: it emits `framework module …`, only valid for a
#   real .framework bundle; our XCFramework wraps a staticlib + headers and
#   needs the plain `module …` (same canImport symptom otherwise).
bindgen --modulemap --modulemap-filename module.modulemap \
  --module-name calamoFFI "$STATICLIB" "$GEN_HEADERS"
echo "-- generated:"; ls "$GEN_SWIFT" "$GEN_HEADERS"

echo "== 3/5 xcodebuild -create-xcframework =="
XCFRAMEWORK="$ROOT/CalamoCore/Frameworks/CalamoFFI.xcframework"
rm -rf "$XCFRAMEWORK"
mkdir -p "$ROOT/CalamoCore/Frameworks"
if ! xcodebuild -create-xcframework \
  -library "$STATICLIB" -headers "$GEN_HEADERS" \
  -output "$XCFRAMEWORK"; then
  echo "xcodebuild -create-xcframework failed — on a fresh Xcode install," >&2
  echo "run \`xcodebuild -runFirstLaunch\` once, then re-run ./build.sh" >&2
  exit 1
fi

SWIFT_BUILD=(swift build -c release --package-path "$ROOT/app")
echo "== 4/5 swift build -c release (menu bar app) =="
"${SWIFT_BUILD[@]}"

echo "== 5/5 assemble build/Calamo.app =="
APP="$ROOT/build/Calamo.app"
BIN="$("${SWIFT_BUILD[@]}" --show-bin-path)/Calamo"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/app/Info.plist" "$APP/Contents/Info.plist"
cp "$BIN" "$APP/Contents/MacOS/Calamo"
# Ad-hoc signature: enough to launch locally. TCC persistence across updates
# will need a stable certificate.
codesign --force --sign - "$APP"

echo "Done → open $APP"
