#!/bin/bash
# Golden suites launcher — calibrated reference machine only, never CI.
# Rules, thresholds and the re-baseline procedure: docs/golden-suites.md.
#
#   scripts/golden.sh [--rite] [asr|cleanup|e2e|live|all]
#
# --rite runs the selection 5 consecutive times (the admission rite): every
# run must be identical — any variance is a bug to diagnose. Rite runs keep
# going after a red run (a constant red still proves determinism, cf. the
# known-red window in the docs); the exit code stays non-zero.
set -euo pipefail
cd "$(dirname "$0")/.."

runs=1
if [[ "${1:-}" == "--rite" ]]; then
  runs=5
  shift
fi
suite="${1:-all}"
status=0

asr() { CALAMO_GOLDEN=1 swift test --package-path app --filter AsrGoldenSuite; }
e2e() { CALAMO_GOLDEN=1 swift test --package-path app --filter E2eGoldenSuite; }
live() { CALAMO_GOLDEN=1 swift test --package-path app --filter LiveGoldenSuite; }
cleanup() {
  CALAMO_GOLDEN=1 cargo test --manifest-path core/Cargo.toml -p calamo-adapters \
    --features llama-cleanup --test cleanup_golden -- --nocapture
}

run_suite() {
  local rc=0
  case "$suite" in
    asr) asr || rc=$? ;;
    cleanup) cleanup || rc=$? ;;
    e2e) e2e || rc=$? ;;
    live) live || rc=$? ;;
    all)
      asr || rc=$?
      cleanup || rc=$?
      e2e || rc=$?
      live || rc=$?
      ;;
    *)
      echo "usage: scripts/golden.sh [--rite] [asr|cleanup|e2e|live|all]" >&2
      exit 2
      ;;
  esac
  return "$rc"
}

for ((run = 1; run <= runs; run++)); do
  ((runs > 1)) && echo "== golden run $run/$runs =="
  run_suite || status=$?
done
exit "$status"
