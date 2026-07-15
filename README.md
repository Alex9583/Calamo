# Calamo

Local-only voice dictation for macOS: hold a hotkey, speak, release — the
cleaned-up text is inserted at the cursor, and not a single byte of audio
leaves the machine. The canonical glossary (ubiquitous language) lives in
[CONTEXT.md](CONTEXT.md).

## Build

Prerequisites:

- Xcode 26+ (`xcodebuild`, `swift`). After a fresh Xcode install, run
  `xcodebuild -runFirstLaunch` once (otherwise `-create-xcframework` fails
  on a broken simulator plug-in).
- Rust 1.97+ with the Apple Silicon target:
  `rustup target add aarch64-apple-darwin`.

```sh
./build.sh            # cargo → uniffi-bindgen-swift → XCFramework → SwiftPM → build/Calamo.app
open build/Calamo.app # menu bar app (waveform icon)
```

The menu displays the marker returned by the Rust stub facade across the
FFI — the proof the whole chain holds.

## Tests

```sh
cargo test --manifest-path core/Cargo.toml   # Rust workspace (no I/O, no models)
swift test --package-path app                # Swift side, through the real FFI (./build.sh first)
```

## Layout

| Path | Role |
|---|---|
| `core/` | Cargo workspace: `calamo-core` (pure domain) ← `calamo-adapters` (Rust-side adapters) ← `calamo-ffi` (UniFFI staticlib) |
| `CalamoCore/` | Local SwiftPM package: XCFramework binaryTarget + generated Swift bindings — both written by `build.sh`, never committed |
| `app/` | The menu bar app (SwiftUI `MenuBarExtra`), consumes `CalamoCore` alongside FluidAudio |
| `build.sh` | The single dev/CI build chain |
| `fixtures/` | Shared test fixtures (`fixtures/audio/local/` is a private corpus, never committed) |
