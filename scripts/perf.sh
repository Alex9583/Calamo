#!/bin/bash
# Perf harness launcher — manual milestone rite on the calibrated reference
# machine, never CI. Trigger rule, report reading and the regression policy:
# docs/perf-harness.md.
#
#   scripts/perf.sh [passes]      # default 3 passes × 15 takes
#
# Release build: debug-compiled Swift (rescoring loops) would skew the
# numbers against the recorded references.
set -euo pipefail
cd "$(dirname "$0")/.."

CALAMO_PERF=1 CALAMO_PERF_PASSES="${1:-3}" \
  swift test -c release --package-path app --filter PerfHarnessSuite
