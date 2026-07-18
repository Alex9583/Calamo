//! Through the exported facade with Rust-implemented foreign ports — the
//! surface Swift consumes. Placeholder internals: every dictation degrades.

use std::sync::{Arc, Condvar, Mutex};
use std::time::Duration;

use calamo_ffi::{
    BoostEntry, DictationEngine, DictationObserver, DictationState, EngineConfig, EngineState,
    InsertionError, InsertionPort, Language, RawTranscript, RefusalCause, TranscriptionError,
    TranscriptionPort,
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
        terminal.clone().unwrap()
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

#[test]
fn a_dictation_travels_the_exported_facade_and_completes_degraded_without_the_cleanup_adapter() {
    // Given
    let insertion = Arc::new(FakeInsertion::default());
    let observer = Arc::new(TerminalObserver::default());
    let engine = DictationEngine::new(
        Arc::new(FakeTranscription),
        Arc::clone(&insertion) as Arc<dyn InsertionPort>,
        Arc::clone(&observer) as Arc<dyn DictationObserver>,
        EngineConfig {
            dictionary_path: "unused-until-ticket-12".to_string(),
            cleanup_model_path: "unused-until-ticket-07".to_string(),
        },
    );
    engine.mark_ready();

    // When
    engine.hotkey_pressed();
    engine.push_audio(vec![0.1, -0.2, 0.3]);
    engine.hotkey_released();

    // Then: degraded — the placeholder cleanup is unavailable by design
    assert_eq!(
        observer.wait_terminal(),
        DictationState::Completed { degraded: true }
    );
    assert_eq!(
        insertion.texts.lock().unwrap().clone(),
        ["pousse la branche sur github"]
    );
}
