# Distribution

Calamo ships without Apple signature or notarization: a DMG on GitHub
Releases plus a personal Homebrew tap. The Gatekeeper friction is an
assumed v1 debt, handled entirely outside the app — the DMG background
and the tap caveats walk the official path, the README the install
steps; the app never mentions it. Cutting a release — ritual,
real-update test, cask bump — is [release.md](release.md).

## Signing — one stable self-signed identity, forever

TCC keys a permission grant to the bundle ID plus the signature's
designated requirement (DR). Ad-hoc DRs are cdhash-based and change on
every build: an ad-hoc update silently loses every user's Accessibility
grant (validated on machine — grant kept under the stable certificate,
lost under bare ad-hoc). So every release carries the same DR,
`identifier "com.calamo.Calamo" and certificate root = H"7fa94556…"`,
anchored by one certificate:

- Created **once** by `scripts/create-signing-identity.sh` and kept
  forever — regenerating it means a new DR and every user re-granting
  after the next update. The private key is the durable secret (back
  it up: whoever holds it can sign an app that inherits Calamo's TCC
  grants); CI gets the pair through the repo secrets
  `CALAMO_SIGNING_CERT_PEM` / `CALAMO_SIGNING_KEY_PEM`.
- `scripts/package.sh` refuses to ship anything else: it byte-compares
  the signed app's leaf certificate against the stable pair.
- Signatures carry no secure timestamp for now; before the certificate
  expires (2036), re-evaluate `codesign --timestamp` (Apple TSA,
  network at signing time).
- Dev builds stay ad-hoc (`build.sh`): the manual checklist documents
  the re-grant dance after each rebuild.

## Why a personal Homebrew tap

The official homebrew-cask already rejects new unsigned casks
(deprecated since Homebrew 5) and sets notability thresholds, so the
cask lives in `Alex9583/homebrew-calamo`, whose canonical source is
`packaging/homebrew-calamo/` in this repo. brew quarantines
its downloads: installing lands on the same Gatekeeper path, printed
by the cask caveats.

## Model attribution

Speech recognition by NVIDIA's Parakeet models —
[parakeet-tdt-0.6b-v3](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3)
and parakeet-tdt_ctc-110m — used under
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), as CoreML
conversions by
[FluidInference](https://huggingface.co/FluidInference). Cleanup by
[Qwen3.5-2B](https://huggingface.co/Qwen/Qwen3.5-2B) (Apache-2.0);
inference through FluidAudio (Apache-2.0) and llama.cpp (MIT).
User-visible in Settings → About.
