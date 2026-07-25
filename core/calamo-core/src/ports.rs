//! The five ports of the hexagon. `TranscriptionPort`, `InsertionPort` and
//! `DictationObserver` are implemented by the Swift shell across the FFI;
//! `CleanupPort` and `DictionaryRepository` stay internal to the Rust core.

use crate::dictation::{CleanedText, DictationId, DictationState, RawTranscript, Utterance};
use crate::dictionary::{Dictionary, DictionaryEntry};
use crate::engine::{EngineState, RefusalCause};

pub trait TranscriptionPort: Send + Sync {
    fn transcribe(
        &self,
        utterance: &Utterance,
        boost_list: &[DictionaryEntry],
    ) -> Result<RawTranscript, TranscriptionError>;
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TranscriptionError {
    pub message: String,
}

/// Never fatal on failure: the engine degrades to the verbatim transcript.
pub trait CleanupPort: Send + Sync {
    fn clean(&self, transcript: &RawTranscript, glossary: &[&str]) -> Result<String, CleanupError>;
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CleanupError {
    pub message: String,
}

pub trait InsertionPort: Send + Sync {
    fn insert(&self, text: &CleanedText) -> Result<(), InsertionError>;
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum InsertionError {
    SecureField,
    Failed { message: String },
}

/// The outbound event channel — no Dictation ends silently.
pub trait DictationObserver: Send + Sync {
    fn dictation_state_changed(&self, dictation: DictationId, state: DictationState);
    fn dictation_refused(&self, cause: RefusalCause);
    fn engine_state_changed(&self, state: EngineState);
}

pub trait DictionaryRepository: Send + Sync {
    fn load(&self) -> Result<Dictionary, DictionaryLoadError>;
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DictionaryLoadError {
    pub message: String,
}
