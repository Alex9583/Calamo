//! The foreign traits the Swift shell implements, and their bridges onto the
//! core's ports.

use std::sync::Arc;

use calamo_core::dictation as core_dictation;
use calamo_core::dictionary::DictionaryEntry;
use calamo_core::engine as core_engine;
use calamo_core::ports as core_ports;

use crate::errors::{InsertionError, TranscriptionError};
use crate::types::{BoostEntry, DictationState, EngineState, RawTranscript, RefusalCause};

#[uniffi::export(with_foreign)]
pub trait TranscriptionPort: Send + Sync {
    fn transcribe(
        &self,
        samples: Vec<f32>,
        boost_list: Vec<BoostEntry>,
    ) -> Result<RawTranscript, TranscriptionError>;
}

#[uniffi::export(with_foreign)]
pub trait InsertionPort: Send + Sync {
    fn insert(&self, text: String) -> Result<(), InsertionError>;
}

#[uniffi::export(with_foreign)]
pub trait DictationObserver: Send + Sync {
    fn dictation_state_changed(&self, dictation: u64, state: DictationState);
    fn dictation_refused(&self, cause: RefusalCause);
    fn engine_state_changed(&self, state: EngineState);
}

pub(crate) struct TranscriptionBridge(pub(crate) Arc<dyn TranscriptionPort>);

impl core_ports::TranscriptionPort for TranscriptionBridge {
    fn transcribe(
        &self,
        utterance: &core_dictation::Utterance,
        boost_list: &[DictionaryEntry],
    ) -> Result<core_dictation::RawTranscript, core_ports::TranscriptionError> {
        let boost_list = boost_list
            .iter()
            .map(|entry| BoostEntry {
                canonical_text: entry.canonical_text().to_string(),
                aliases: entry.aliases().to_vec(),
            })
            .collect();
        self.0
            .transcribe(utterance.samples().to_vec(), boost_list)
            .map(|t| core_dictation::RawTranscript::new(t.text))
            .map_err(|e| core_ports::TranscriptionError {
                message: e.to_string(),
            })
    }
}

pub(crate) struct InsertionBridge(pub(crate) Arc<dyn InsertionPort>);

impl core_ports::InsertionPort for InsertionBridge {
    fn insert(&self, text: &core_dictation::CleanedText) -> Result<(), core_ports::InsertionError> {
        self.0
            .insert(text.as_str().to_string())
            .map_err(|e| match e {
                InsertionError::SecureField => core_ports::InsertionError::SecureField,
                InsertionError::Failed { message } => {
                    core_ports::InsertionError::Failed { message }
                }
            })
    }
}

pub(crate) struct ObserverBridge(pub(crate) Arc<dyn DictationObserver>);

impl core_ports::DictationObserver for ObserverBridge {
    fn dictation_state_changed(
        &self,
        dictation: core_dictation::DictationId,
        state: core_dictation::DictationState,
    ) {
        self.0.dictation_state_changed(dictation.0, state.into());
    }

    fn dictation_refused(&self, cause: core_engine::RefusalCause) {
        self.0.dictation_refused(cause.into());
    }

    fn engine_state_changed(&self, state: core_engine::EngineState) {
        self.0.engine_state_changed(state.into());
    }
}
