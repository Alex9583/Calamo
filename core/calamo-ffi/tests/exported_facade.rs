//! Through the exported facade with Rust-implemented foreign ports — the
//! surface Swift consumes. Cleanup is never loaded here: every dictation
//! degrades.

use std::path::{Path, PathBuf};
use std::sync::{Arc, Condvar, Mutex};
use std::time::Duration;

use calamo_ffi::{
    BoostEntry, DictationEngine, DictationObserver, DictationState, DictionaryLoadError,
    EngineConfig, EngineState, InsertionError, InsertionPort, Language, RawTranscript,
    RefusalCause, TranscriptionError, TranscriptionPort,
};

struct FakeTranscription;

impl TranscriptionPort for FakeTranscription {
    fn transcribe(
        &self,
        _samples: Vec<f32>,
        _boost_list: Vec<BoostEntry>,
    ) -> Result<RawTranscript, TranscriptionError> {
        Ok(RawTranscript {
            text: "pousse la branche sur github".to_string(),
            language: Language::French,
        })
    }
}

#[derive(Default)]
struct FakeInsertion {
    texts: Mutex<Vec<String>>,
}

impl InsertionPort for FakeInsertion {
    fn insert(&self, text: String) -> Result<(), InsertionError> {
        self.texts.lock().unwrap().push(text);
        Ok(())
    }
}

#[derive(Default)]
struct TerminalObserver {
    terminal: Mutex<Option<DictationState>>,
    arrived: Condvar,
}

impl TerminalObserver {
    /// Pops the state so consecutive dictations each get their own wait.
    fn wait_terminal(&self) -> DictationState {
        let mut terminal = self.terminal.lock().unwrap();
        while terminal.is_none() {
            let (guard, timeout) = self
                .arrived
                .wait_timeout(terminal, Duration::from_secs(2))
                .unwrap();
            terminal = guard;
            if timeout.timed_out() {
                panic!("no terminal state reached");
            }
        }
        terminal.take().unwrap()
    }
}

impl DictationObserver for TerminalObserver {
    fn dictation_state_changed(&self, _dictation: u64, state: DictationState) {
        if matches!(
            state,
            DictationState::Completed { .. } | DictationState::Failed { .. }
        ) {
            *self.terminal.lock().unwrap() = Some(state);
            self.arrived.notify_all();
        }
    }

    fn dictation_refused(&self, _cause: RefusalCause) {}

    fn engine_state_changed(&self, _state: EngineState) {}
}

struct Harness {
    insertion: Arc<FakeInsertion>,
    observer: Arc<TerminalObserver>,
    engine: Arc<DictationEngine>,
}

/// Fresh per test: tests run in parallel within one process.
fn dictionary_path(test: &str) -> PathBuf {
    let dir = std::env::temp_dir().join(format!("calamo-facade-{}-{test}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    std::fs::create_dir_all(&dir).unwrap();
    dir.join("dictionary.toml")
}

fn empty_dictionary(test: &str) -> PathBuf {
    let path = dictionary_path(test);
    std::fs::write(&path, "entries = []\n").unwrap();
    path
}

fn ready_engine(dictionary_path: &Path, cleanup_model_path: &str) -> Harness {
    let insertion = Arc::new(FakeInsertion::default());
    let observer = Arc::new(TerminalObserver::default());
    let engine = DictationEngine::new(
        Arc::new(FakeTranscription),
        Arc::clone(&insertion) as Arc<dyn InsertionPort>,
        Arc::clone(&observer) as Arc<dyn DictationObserver>,
        EngineConfig {
            dictionary_path: dictionary_path.display().to_string(),
            cleanup_model_path: cleanup_model_path.to_string(),
        },
    );
    engine.mark_ready();
    Harness {
        insertion,
        observer,
        engine,
    }
}

impl Harness {
    fn dictate(&self) {
        self.engine.hotkey_pressed();
        self.engine.push_audio(vec![0.1, -0.2, 0.3]);
        self.engine.hotkey_released();
    }

    fn assert_completed_degraded_with_verbatim(&self) {
        assert_eq!(
            self.observer.wait_terminal(),
            DictationState::Completed { degraded: true }
        );
        assert_eq!(
            self.insertion.texts.lock().unwrap().clone(),
            ["pousse la branche sur github"]
        );
    }
}

#[test]
fn given_cleanup_never_loaded_when_a_dictation_travels_the_exported_facade_then_it_completes_degraded_with_the_verbatim(
) {
    // Given
    let harness = ready_engine(&empty_dictionary("degraded"), "never-loaded.gguf");

    // When
    harness.dictate();

    // Then: degraded — the cleanup slot is empty by design
    harness.assert_completed_degraded_with_verbatim();
}

#[test]
fn given_a_bogus_cleanup_model_path_when_load_cleanup_fails_and_a_dictation_runs_then_it_still_completes_degraded(
) {
    // Given
    let harness = ready_engine(&empty_dictionary("bogus-gguf"), "/nonexistent/model.gguf");

    // When: the load fails and a dictation runs anyway
    let loaded = harness.engine.load_cleanup();
    harness.dictate();

    // Then: never fatal — the verbatim transcript still lands
    assert!(loaded.is_err());
    harness.assert_completed_degraded_with_verbatim();
}

#[test]
fn given_no_dictionary_file_when_the_engine_starts_then_the_template_is_created_and_its_spellings_enforced(
) {
    // Given: a first launch — dictionary.toml does not exist yet
    let path = dictionary_path("first-launch");
    let harness = ready_engine(&path, "never-loaded.gguf");

    // When
    harness.dictate();

    // Then: the auto-documented template exists and its GitHub example
    // already corrects the verbatim
    assert!(path.is_file(), "dictionary.toml was not created");
    assert_eq!(
        harness.observer.wait_terminal(),
        DictationState::Completed { degraded: true }
    );
    assert_eq!(
        harness.insertion.texts.lock().unwrap().clone(),
        ["pousse la branche sur GitHub"]
    );
}

#[test]
fn given_a_broken_then_fixed_dictionary_when_reloaded_then_the_error_carries_the_line_and_recovery_resumes(
) {
    // Given
    let path = empty_dictionary("reload-cycle");
    let harness = ready_engine(&path, "never-loaded.gguf");

    // When: the file breaks
    std::fs::write(&path, "entries = [\n    { text = \"GitHub\"\n]\n").unwrap();
    let broken = harness.engine.reload_dictionary();

    // Then: line and cause reach the caller, the previous dictionary stays
    assert!(
        matches!(
            broken,
            Err(DictionaryLoadError::Invalid { line: Some(2), .. })
        ),
        "unexpected reload outcome: {broken:?}"
    );
    harness.dictate();
    harness.assert_completed_degraded_with_verbatim();

    // When: the user fixes the file
    std::fs::write(&path, "entries = [\n    { text = \"Branche\" },\n]\n").unwrap();
    let fixed = harness.engine.reload_dictionary();

    // Then: reload resumes and the next dictation uses the new entries
    assert_eq!(fixed, Ok(()));
    harness.dictate();
    assert_eq!(
        harness.observer.wait_terminal(),
        DictationState::Completed { degraded: true }
    );
    assert_eq!(
        harness.insertion.texts.lock().unwrap().last().unwrap(),
        "pousse la Branche sur github"
    );
}
