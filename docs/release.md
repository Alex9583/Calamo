# Release ritual

Runs on the reference machine, before every tag. Every gate green, every
deviation ticketed or fixed before the tag; results recorded in the
release PR description.

1. **Golden suites** — `scripts/golden.sh all`; paste the reports in the
   release PR ([golden-suites.md](golden-suites.md)).
2. **Perf harness** — `scripts/perf.sh`; p90 < 2 s for ~10 s dictations,
   compared against the private baseline — an unexplained regression is
   a release blocker ([perf-harness.md](perf-harness.md)).
3. **Manual checklist** — a full pass of
   [manual-checklist.md](manual-checklist.md).
4. **Real update test** — below; proves the promise the signing strategy
   exists for.
5. **Tag** — merge the release PR with a `patch` / `minor` / `major`
   label: tag-release.yml bumps from the latest tag, pushes `vX.Y.Z` and
   dispatches the release workflow, which builds, signs with the stable
   identity, packages the DMG and publishes the GitHub Release — its
   SHA-256 plus the GitHub-generated changelog
   ([distribution.md](distribution.md)). Rehearse beforehand without
   publishing via the release workflow's manual dispatch from a branch.
   Escape hatch: a hand-pushed `git tag vX.Y.Z` still triggers the same
   build.
6. **Cask bump** — copy `packaging/homebrew-calamo/` over the
   `Alex9583/homebrew-calamo` repo, set `version` and `sha256` from the
   release notes, push, then `brew update && brew upgrade --cask calamo`
   on any machine to confirm.

## Real update test

An update must keep the permissions the user already granted — TCC keys
them to the stable certificate's designated requirement. With version N
installed in /Applications, granted (micro + Accessibility) and working:

1. Build the N+1 candidate DMG (the tag's workflow artifact, or locally
   `./build.sh && scripts/package.sh <next-version>`).
2. Mount it, drag Calamo.app over /Applications (Replace), launch —
   walking Gatekeeper's "Open Anyway" again is expected, the download is
   re-quarantined.
3. Expect: **no permission prompt of any kind**; the ambient
   « Optimizing after update… (~1 min, once) » status line while the ANE
   cache recompiles, self-clearing at Ready; then a dictation lands
   without touching System Settings.
4. Any TCC re-prompt or a phantom grant (switch on in System Settings
   but dictation refused) is a release blocker: check the DR of both
   builds (`codesign -dr - /Applications/Calamo.app`) — they must be
   byte-identical.

For the first release, with no version N in the wild: package a second
local candidate with a bumped version and walk the same steps between
the two candidates.

## First-time setup (already done, kept for disaster recovery)

- The signing identity and its backup discipline:
  [distribution.md](distribution.md). Restore the secrets from the PEM
  pair with `gh secret set CALAMO_SIGNING_CERT_PEM` /
  `…_KEY_PEM`.
- The tap repo `Alex9583/homebrew-calamo` is created from
  `packaging/homebrew-calamo/` at the first release.
