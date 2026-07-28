//! The exported `DictationEngine`, wiring the foreign ports and the core's
//! internal adapters.

use std::sync::Arc;

use calamo_adapters::dictionary::TomlDictionaryRepository;
use calamo_core::engine as core_engine;
use calamo_core::ports as core_ports;

use crate::cleanup::DeferredCleanup;
use crate::errors::{CleanupLoadError, DictionaryLoadError};
use crate::ports::{
    DictationObserver, InsertionBridge, InsertionPort, ObserverBridge, TranscriptionBridge,
    TranscriptionPort,
};
use crate::types::{CaptureIncident, EngineConfig, UnavailabilityCause};

#[derive(uniffi::Object)]
pub struct DictationEngine {
    inner: core_engine::DictationEngine,
    cleanup: Arc<DeferredCleanup>,
    config: EngineConfig,
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
        let cleanup = Arc::new(DeferredCleanup::new());
        let inner = core_engine::DictationEngine::new(
            Arc::new(TranscriptionBridge(transcription)),
            Arc::clone(&cleanup) as Arc<dyn core_ports::CleanupPort>,
            Arc::new(InsertionBridge(insertion)),
            Arc::new(ObserverBridge(observer)),
            Arc::new(TomlDictionaryRepository::at(&config.dictionary_path)),
        );
        Arc::new(Self {
            inner,
            cleanup,
            config,
        })
    }

    /// Blocks while the pinned GGUF loads onto Metal — call it off the main
    /// thread, before `mark_ready`. On failure the engine stays usable:
    /// every dictation completes degraded.
    pub fn load_cleanup(&self) -> Result<(), CleanupLoadError> {
        self.cleanup
            .load(&self.config.cleanup_model_path)
            .map_err(|message| CleanupLoadError::Failed { message })
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

    /// On failure the previous dictionary stays active; the shell turns the
    /// error into a notification.
    pub fn reload_dictionary(&self) -> Result<(), DictionaryLoadError> {
        self.inner.reload_dictionary().map_err(Into::into)
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
