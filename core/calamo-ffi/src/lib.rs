//! calamo-ffi — the UniFFI boundary: the `DictationEngine` facade and the
//! three foreign traits.

// Pins the generated artefact names (calamo.swift, the calamoFFI C module)
// whatever this crate is called.
uniffi::setup_scaffolding!("calamo");

mod cleanup;
mod convert;
mod errors;
mod facade;
mod ports;
mod types;

pub use errors::{CleanupLoadError, InsertionError, TranscriptionError};
pub use facade::DictationEngine;
pub use ports::{DictationObserver, InsertionPort, TranscriptionPort};
pub use types::*;
