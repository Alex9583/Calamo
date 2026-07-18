//! calamo-core — the pure domain crate. It owns the whole domain and the
//! pipeline orchestration; it never touches I/O, models, or the FFI.

pub mod dictation;
pub mod dictionary;
pub mod engine;
mod matching;
pub mod ports;
pub mod spelling_enforcement;
