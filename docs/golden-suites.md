# Golden suites

Four on-demand suites replay the private corpora — the 15-take reference
corpus and the 6-take live corpus — against the real pipeline. They never
run in CI and never run implicitly: each one requires `CALAMO_GOLDEN=1` and
the calibrated reference machine — anywhere else a requested run fails
loudly.

| Suite | Chain under test | Harness | Launch |
|---|---|---|---|
| ASR | audio → RawTranscript (boosted FluidAudio adapter) | `app/Tests/CalamoGoldenTests` | `scripts/golden.sh asr` |
| Cleanup | verbatim → CleanedText (Qwen3.5-2B + SpellingEnforcement) | `core/calamo-adapters/tests/cleanup_golden` | `scripts/golden.sh cleanup` |
| E2E | audio → inserted text (`DictationEngine`, insertion doubled, reference dictionary hot-edited mid-suite) | `app/Tests/CalamoGoldenTests` | `scripts/golden.sh e2e` |
| Live | audio → RawTranscript (template dictionary boosted over live-condition takes) | `app/Tests/CalamoGoldenTests` | `scripts/golden.sh live` |

Each suite prints a per-take report and asserts two layers:

- **Hard, per take** — exact language of the final text (E2E — the cleanup
  must never translate), zero never-spoken terms, exact dictionary
  spellings (cleanup, E2E); a boosted term appearing more often than the
  take dictated it (live). No tolerance.
- **Statistical, literal in `fixtures/*-golden.json`, never recomputed** —
  aggregate WER FR ≤ 8 % and EN ≤ 6.5 % (ASR); normalized Levenshtein
  similarity vs `clean` ≥ 0.90 per take with a budget of 2 takes below
  (cleanup, E2E). The live suite has no statistical layer: its checks are
  absolute.

## The live corpus and the small-dictionary regime

The reference corpus boosts ~51 terms; a real dictionary starts at 3. Below
FluidAudio's 10-term threshold the rescorer behaves differently (that regime
once enabled an acoustic rescue that replaced normal words with dictionary
entries on live audio while every golden suite stayed green). The live
corpus exists to pin that regime: the shipped template dictionary
(`live-contract.json` mirrors it, guarded in CI) boosted over short real-mic
takes recorded in live conditions — fast pace, ambient noise, the exact
phrases that corrupted in manual passes. Recording recipe and scripts:
`fixtures/audio/README.md`.

Latency is out of golden scope: the perf harness owns it
([perf-harness.md](perf-harness.md)).

## Calibration — the pinned environment

Golden outputs only bind on the reference environment: one calibrated
machine (chip, memory, macOS) plus the exact model stack — FluidAudio and
the Parakeet models, the boost threshold, the pinned GGUF, llama-cpp-2,
the cleanup prompt version. The authoritative values live in the baselines
themselves (`fixtures/audio/local/golden/*-baseline.json`, private, next
to the corpus): every baseline records the environment it was captured on
and every run re-checks it — a mismatch fails the suite until you
re-baseline.

## Re-baseline rule

**Any machine or stack change — chip, macOS, FluidAudio, models, llama.cpp,
prompt — invalidates the calibration.** A red golden after a deliberate
update is the test doing its job, not a flake. To re-baseline:

1. Delete the suite's baseline file under `fixtures/audio/local/golden/`.
2. Run the suite once (it bootstraps a new baseline), review every diff.
3. Pass the admission rite below, then commit the change in a dedicated
   commit that documents the environment change (baselines themselves stay
   private; paste the report).

## Admission rite

A new or re-baselined suite is declared stable only after **5 consecutive
identical runs** on the reference machine: `scripts/golden.sh --rite <suite>`.
Greedy decoding and batch ASR make runs byte-identical — any run-to-run
variance is a bug to diagnose, never a threshold to widen.

## The E2E dictionary and the hot-edit demo

The E2E suite writes the transcription contract's vocabulary as a real
`dictionary.toml` and opens with the hot-edit demo: mx-01 dictated without
« Design System » lands with some other spelling; the entry is added to the
TOML and hot-reloaded — same engine, no restart — and the redictated take
must carry the exact spelling. The corpus then replays with the full
reference dictionary: boost, prompt glossary and SpellingEnforcement all
live.

## Cadence

Any change that touches the real pipeline — adapter code, cleanup prompt,
model versions, boost thresholds, SpellingEnforcement — requires a golden
run before merge, report pasted into the commit or PR message.
