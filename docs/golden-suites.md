# Golden suites

Three on-demand suites replay the 15-take reference corpus against the real
pipeline. They never run in CI and never run implicitly: each one requires
`CALAMO_GOLDEN=1` and the calibrated reference machine — anywhere else a
requested run fails loudly.

| Suite | Chain under test | Harness | Launch |
|---|---|---|---|
| ASR | audio → RawTranscript (boosted FluidAudio adapter) | `app/Tests/CalamoGoldenTests` | `scripts/golden.sh asr` |
| Cleanup | verbatim → CleanedText (Qwen3.5-2B + SpellingEnforcement) | `core/calamo-adapters/tests/cleanup_golden` | `scripts/golden.sh cleanup` |
| E2E | audio → inserted text (`DictationEngine`, insertion doubled) | `app/Tests/CalamoGoldenTests` | `scripts/golden.sh e2e` |

Each suite prints a per-take report and asserts two layers:

- **Hard, per take** — exact detected language (ASR, E2E), zero never-spoken
  terms, exact dictionary spellings (cleanup, E2E). No tolerance.
- **Statistical, literal in `fixtures/*-golden.json`, never recomputed** —
  aggregate WER FR ≤ 8 % and EN ≤ 6.5 % (ASR); normalized Levenshtein
  similarity vs `clean` ≥ 0.90 per take with a budget of 2 takes below
  (cleanup, E2E).

Latency is out of golden scope: the perf harness (ticket 21) owns it.

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

## Known red: E2E spelling until ticket 13

The walking skeleton pins an empty dictionary in the facade, so the E2E
chain runs unboosted, glossary-less, with SpellingEnforcement as a no-op.
One hard assertion is red on the current baseline — mx-01 « design system »
not spelled « Design System » — and stays red until ticket 13 wires
`boostList()` / `promptGlossary()` / SpellingEnforcement end to end; that
ticket's acceptance explicitly includes turning this golden green. Everything
else (language 15/15, zero never-spoken terms, similarity budget 2/2) holds.

## Cadence

Any change that touches the real pipeline — adapter code, cleanup prompt,
model versions, boost thresholds, SpellingEnforcement — requires a golden
run before merge, report pasted into the commit or PR message.
