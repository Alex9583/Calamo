# Perf harness

The latency milestone rite. `scripts/perf.sh` replays the 15-take reference
corpus through the real `DictationEngine` chain — FluidAudio ASR, Qwen3.5-2B
cleanup, SpellingEnforcement, insertion doubled — warm, in one process, and
**asserts p90 < 2 s between hotkey release and insertion for ~10 s
dictations** (the spec budget). Latency is deliberately out of the golden
suites: this harness is the authority.

## Trigger rule — never CI

The harness runs by hand, on the calibrated reference machine, and never in
CI — anywhere else the numbers mean nothing. Run it:

- before each release;
- after any model change — Parakeet/FluidAudio models, the pinned GGUF, the
  cleanup prompt version;
- after any inference-stack change — FluidAudio or llama-cpp-2 version,
  boost thresholds, engine pipeline code.

## Launch and shape

```
scripts/perf.sh [passes]    # default 3 passes × 15 takes = 45 dictations
```

Release build (`swift test -c release`, gated by `CALAMO_PERF=1`): the
first dictation warms the chain and is excluded, then every take replays in
corpus order for the requested passes. Each dictation prints its release →
insertion latency decomposed by stage — FFI dispatch, ASR, cleanup, spelling
pass — followed by the aggregate report: median / p90 / max per stage, the
9–13 s band (the "~10 s dictation" of the budget), and the process-lifetime
peak `phys_footprint`.

## Regression rule

The accepted numbers live in the private baseline next to the corpus,
`fixtures/audio/local/golden/perf-baseline.md`, overwritten at each accepted
run. Compare each run against it. **An unexplained regression is a release 
blocker** — either the cause is a deliberate change (model, stack, macOS) 
and the baseline is overwritten with the new numbers and the explanation, 
or the regression is diagnosed and fixed. A greener run after a deliberate 
change is recorded the same way.
