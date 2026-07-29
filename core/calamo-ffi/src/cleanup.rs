//! The core-internal `CleanupPort` as the app lives it: every clean degrades
//! until the shell has the facade load the pinned GGUF. The real adapter only
//! exists behind `llama-cleanup` on macOS — same condition as in
//! calamo-adapters — so the portable CI build never compiles llama.cpp.

use calamo_core::dictation::RawTranscript;
use calamo_core::ports::{CleanupError, CleanupPort};

#[cfg(all(feature = "llama-cleanup", target_os = "macos"))]
use calamo_adapters::cleanup::LlamaCleanup;

#[cfg(not(all(feature = "llama-cleanup", target_os = "macos")))]
const NOT_COMPILED: &str = "built without the llama-cleanup feature";

pub(crate) struct DeferredCleanup {
    #[cfg(all(feature = "llama-cleanup", target_os = "macos"))]
    slot: std::sync::RwLock<Option<LlamaCleanup>>,
}

impl DeferredCleanup {
    pub(crate) fn new() -> Self {
        Self {
            #[cfg(all(feature = "llama-cleanup", target_os = "macos"))]
            slot: std::sync::RwLock::new(None),
        }
    }

    #[cfg(all(feature = "llama-cleanup", target_os = "macos"))]
    pub(crate) fn load(&self, gguf: &str) -> Result<(), String> {
        let adapter = LlamaCleanup::load(std::path::Path::new(gguf)).map_err(|e| e.to_string())?;
        *self.slot.write().unwrap() = Some(adapter);
        Ok(())
    }

    #[cfg(not(all(feature = "llama-cleanup", target_os = "macos")))]
    pub(crate) fn load(&self, _gguf: &str) -> Result<(), String> {
        Err(NOT_COMPILED.to_string())
    }
}

impl CleanupPort for DeferredCleanup {
    #[cfg(all(feature = "llama-cleanup", target_os = "macos"))]
    fn clean(&self, transcript: &RawTranscript, glossary: &[&str]) -> Result<String, CleanupError> {
        match &*self.slot.read().unwrap() {
            Some(adapter) => adapter.clean(transcript, glossary),
            None => Err(CleanupError {
                message: "cleanup model not loaded".to_string(),
            }),
        }
    }

    #[cfg(not(all(feature = "llama-cleanup", target_os = "macos")))]
    fn clean(
        &self,
        _transcript: &RawTranscript,
        _glossary: &[&str],
    ) -> Result<String, CleanupError> {
        Err(CleanupError {
            message: NOT_COMPILED.to_string(),
        })
    }

    // Before the model loads there is no prefix to warm; the facade warms
    // again once the load completes.
    #[cfg(all(feature = "llama-cleanup", target_os = "macos"))]
    fn warm_glossary(&self, glossary: &[&str]) {
        if let Some(adapter) = &*self.slot.read().unwrap() {
            adapter.warm_glossary(glossary);
        }
    }
}
