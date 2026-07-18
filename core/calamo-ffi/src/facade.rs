//! The exported `DictationEngine`, wiring the foreign ports and the core's
//! internal adapters (placeholders until tickets 07 and 12).

use std::sync::Arc;

use calamo_core::dictation as core_dictation;
use calamo_core::dictionary::Dictionary;
use calamo_core::engine as core_engine;
use calamo_core::ports as core_ports;

use crate::ports::{
    DictationObserver, InsertionBridge, InsertionPort, ObserverBridge, TranscriptionBridge,
    TranscriptionPort,
};
use crate::types::{CaptureIncident, EngineConfig, UnavailabilityCause};

/// Until ticket 07 wires llama.cpp: every dictation completes degraded.
struct CleanupUnavailable;

impl core_ports::CleanupPort for CleanupUnavailable {
    fn clean(
        &self,
        _transcript: &core_dictation::RawTranscript,
        _glossary: &[&str],
    ) -> Result<String, core_ports::CleanupError> {
        Err(core_ports::CleanupError {
            message: "cleanup adapter not wired yet (ticket 07)".to_string(),
        })
    }
}

/// Until ticket 12 wires dictionary.toml, the dictionary is empty.
struct EmptyDictionaryRepository;

impl core_ports::DictionaryRepository for EmptyDictionaryRepository {
    fn load(&self) -> Result<Dictionary, core_ports::DictionaryLoadError> {
        Ok(Dictionary::new(Vec::new()).expect("empty dictionary is valid"))
    }
}

#[derive(uniffi::Object)]
pub struct DictationEngine {
    inner: core_engine::DictationEngine,
    /// Held for the internal adapters of tickets 07 and 12.
    _config: EngineConfig,
}

#[uniffi::export]
impl DictationEngine {
    #[uniffi::constructor]
    pub fn new(
        transcription: Arc<dyn TranscriptionPort>,
        insertion: Arc<dyn InsertionPort>,
        observer: Arc<dyn DictationObserver>,
        config: EngineConfig,
    ) -> Arc<Self> {
        let inner = core_engine::DictationEngine::new(
            Arc::new(TranscriptionBridge(transcription)),
            Arc::new(CleanupUnavailable),
            Arc::new(InsertionBridge(insertion)),
            Arc::new(ObserverBridge(observer)),
            Arc::new(EmptyDictionaryRepository),
        );
        Arc::new(Self {
            inner,
            _config: config,
        })
    }

    pub fn hotkey_pressed(&self) {
        self.inner.hotkey_pressed();
    }

    pub fn hotkey_released(&self) {
        self.inner.hotkey_released();
    }

    /// ~100 ms chunks, mono 16 kHz f32.
    pub fn push_audio(&self, samples: Vec<f32>) {
        self.inner.push_audio(&samples);
    }

    pub fn reload_dictionary(&self) {
        self.inner.reload_dictionary();
    }

    pub fn capture_failed(&self, incident: CaptureIncident) {
        self.inner.capture_failed(incident.into());
    }

    pub fn mark_loading(&self) {
        self.inner.mark_loading();
    }

    pub fn mark_ready(&self) {
        self.inner.mark_ready();
    }

    pub fn mark_unavailable(&self, cause: UnavailabilityCause) {
        self.inner.mark_unavailable(cause.into());
    }
}
