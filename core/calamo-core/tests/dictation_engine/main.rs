//! The whole domain through its principal seam — the `DictationEngine`
//! facade — with doubles for the five ports; the aggregates are exercised
//! only through complete scenarios, never by their internals.

mod support;

mod clean_failures;
mod concurrency;
mod dictionary_reload;
mod engine_state_gate;
mod graceful_degradation;
mod nominal_cycle;
mod teardown;
