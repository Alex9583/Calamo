//! The facade wired to the five doubles.

use std::sync::Arc;

use calamo_core::dictation::DictationId;
use calamo_core::dictionary::Dictionary;
use calamo_core::engine::DictationEngine;
use calamo_core::ports::{
    CleanupPort, DictationObserver, DictionaryRepository, InsertionPort, TranscriptionPort,
};

use super::{
    RecordingInsertion, RecordingObserver, ScriptedCleanup, ScriptedTranscription, StubRepository,
};

pub struct Harness {
    pub engine: DictationEngine,
    pub observer: Arc<RecordingObserver>,
    pub transcription: Arc<ScriptedTranscription>,
    pub cleanup: Arc<ScriptedCleanup>,
    pub insertion: Arc<RecordingInsertion>,
    pub repository: Arc<StubRepository>,
}

impl Harness {
    fn build(prime_repository: impl FnOnce(&StubRepository)) -> Self {
        let observer = RecordingObserver::new();
        let transcription = ScriptedTranscription::new();
        let cleanup = ScriptedCleanup::new();
        let insertion = RecordingInsertion::new();
        let repository = StubRepository::new();
        prime_repository(&repository);
        let engine = DictationEngine::new(
            Arc::clone(&transcription) as Arc<dyn TranscriptionPort>,
            Arc::clone(&cleanup) as Arc<dyn CleanupPort>,
            Arc::clone(&insertion) as Arc<dyn InsertionPort>,
            Arc::clone(&observer) as Arc<dyn DictationObserver>,
            Arc::clone(&repository) as Arc<dyn DictionaryRepository>,
        );
        Self {
            engine,
            observer,
            transcription,
            cleanup,
            insertion,
            repository,
        }
    }

    /// An engine as constructed: still Loading.
    pub fn loading() -> Self {
        Self::build(|_| {})
    }

    pub fn ready() -> Self {
        let harness = Self::loading();
        harness.engine.mark_ready();
        harness
    }

    /// The dictionary comes from the repository, loaded at construction.
    pub fn ready_with_dictionary(dictionary: Dictionary) -> Self {
        let harness = Self::build(|repository| repository.holds(dictionary));
        harness.engine.mark_ready();
        harness
    }

    /// One full push-to-talk gesture: press, push the samples, release.
    pub fn dictate(&self, samples: &[f32]) -> DictationId {
        self.engine.hotkey_pressed();
        self.engine.push_audio(samples);
        self.engine.hotkey_released();
        *self.observer.born_dictations().last().unwrap()
    }
}
