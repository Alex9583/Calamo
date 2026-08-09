# Calamo

Local-only voice dictation for macOS: hold a hotkey, speak, release — the
cleaned-up text is inserted at the cursor, and not a single byte of audio
leaves the machine. The canonical glossary (ubiquitous language) lives in
[CONTEXT.md](CONTEXT.md).

## Install

Download the latest DMG from the
[Releases](https://github.com/Alex9583/Calamo/releases) page — drag
Calamo into /Applications **first**, then walk the Gatekeeper path
pictured on the DMG (System Settings → Privacy & Security → "Open
Anyway"). Or:

```sh
brew tap alex9583/calamo
brew install --cask calamo
```

Signing story, tap, model attribution:
[docs/distribution.md](docs/distribution.md).

## Build

Prerequisites:

- Xcode 26+ (`xcodebuild`, `swift`). After a fresh Xcode install, run
  `xcodebuild -runFirstLaunch` once (otherwise `-create-xcframework` fails
  on a broken simulator plug-in).
- Rust 1.97+ with the Apple Silicon target:
  `rustup target add aarch64-apple-darwin`.
- SwiftLint (`brew install swiftlint`) — function-length lint, a CI barrier.

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
scripts/golden.sh all                        # golden suites, reference machine only — docs/golden-suites.md
cargo clippy --workspace --all-targets --manifest-path core/Cargo.toml
swiftlint                                    # both lint function length — docs/standards/small-units.md
```

Before merging a release PR, the manual pass in
[docs/manual-checklist.md](docs/manual-checklist.md) walks the OS glue no
harness can drive — event tap, TCC, real apps, real microphones — and the
error policy end to end.

## CI

Every push runs [ci.yml](.github/workflows/ci.yml), the only automatic merge
barrier: SwiftLint, full build chain, clippy + `swift test` on macOS;
clippy + `cargo test` on Linux (portability). CI never touches models, goldens, or audio fixtures — those
stay local.

Tags `v*` run [release.yml](.github/workflows/release.yml) — a signed
DMG published as a GitHub Release; the ritual around it is
[docs/release.md](docs/release.md).

## Layout

| Path | Role |
|---|---|
| `core/` | Cargo workspace: `calamo-core` (pure domain) ← `calamo-adapters` (Rust-side adapters) ← `calamo-ffi` (UniFFI staticlib) |
| `CalamoCore/` | Local SwiftPM package: XCFramework binaryTarget + generated Swift bindings — both written by `build.sh`, never committed |
| `app/` | The menu bar app (SwiftUI `MenuBarExtra`), consumes `CalamoCore` alongside FluidAudio |
| `build.sh` | The single dev/CI build chain |
| `packaging/` | Canonical source of the Homebrew tap (`homebrew-calamo/`) |
| `fixtures/` | Shared test fixtures (`fixtures/audio/local/` is a private corpus, never committed) |
