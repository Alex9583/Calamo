//! Records everything the engine tells the outside world.

use std::sync::{Arc, Condvar, Mutex};
use std::time::Instant;

use calamo_core::dictation::{DictationId, DictationState};
use calamo_core::engine::{EngineState, RefusalCause};
use calamo_core::ports::DictationObserver;

use super::WAIT;

/// One observer event, in arrival order.
#[derive(Debug, Clone, PartialEq)]
pub enum Observed {
    Dictation(DictationId, DictationState),
    Refused(RefusalCause),
    Engine(EngineState),
}

pub struct RecordingObserver {
    events: Mutex<Vec<Observed>>,
    arrived: Condvar,
}

impl RecordingObserver {
    pub(super) fn new() -> Arc<Self> {
        Arc::new(Self {
            events: Mutex::new(Vec::new()),
            arrived: Condvar::new(),
        })
    }

    pub fn events(&self) -> Vec<Observed> {
        self.events.lock().unwrap().clone()
    }

    pub fn refusals(&self) -> Vec<RefusalCause> {
        self.events()
            .into_iter()
            .filter_map(|e| match e {
                Observed::Refused(cause) => Some(cause),
                _ => None,
            })
            .collect()
    }

    pub fn states_of(&self, id: DictationId) -> Vec<DictationState> {
        self.events()
            .into_iter()
            .filter_map(|e| match e {
                Observed::Dictation(seen, state) if seen == id => Some(state),
                _ => None,
            })
            .collect()
    }

    /// Every dictation that was born (observed Capturing).
    pub fn born_dictations(&self) -> Vec<DictationId> {
        self.events()
            .into_iter()
            .filter_map(|e| match e {
                Observed::Dictation(id, DictationState::Capturing) => Some(id),
                _ => None,
            })
            .collect()
    }

    pub fn only_dictation(&self) -> DictationId {
        let born = self.born_dictations();
        assert_eq!(born.len(), 1, "expected exactly one dictation: {born:?}");
        born[0]
    }

    pub fn wait_until(
        &self,
        expectation: &str,
        pred: impl Fn(&[Observed]) -> bool,
    ) -> Vec<Observed> {
        let deadline = Instant::now() + WAIT;
        let mut events = self.events.lock().unwrap();
        while !pred(&events) {
            let Some(remaining) = deadline.checked_duration_since(Instant::now()) else {
                panic!("timed out waiting for {expectation}; observed: {events:#?}");
            };
            events = self.arrived.wait_timeout(events, remaining).unwrap().0;
        }
        events.clone()
    }

    pub fn wait_terminal(&self, id: DictationId) -> DictationState {
        let terminal = |state: &DictationState| {
            matches!(
                state,
                DictationState::Completed { .. } | DictationState::Failed { .. }
            )
        };
        self.wait_until("a terminal state", |events| {
            events
                .iter()
                .any(|e| matches!(e, Observed::Dictation(seen, s) if *seen == id && terminal(s)))
        });
        self.states_of(id).pop().unwrap()
    }

    fn record(&self, event: Observed) {
        self.events.lock().unwrap().push(event);
        self.arrived.notify_all();
    }
}

impl DictationObserver for RecordingObserver {
    fn dictation_state_changed(&self, dictation: DictationId, state: DictationState) {
        self.record(Observed::Dictation(dictation, state));
    }

    fn dictation_refused(&self, cause: RefusalCause) {
        self.record(Observed::Refused(cause));
    }

    fn engine_state_changed(&self, state: EngineState) {
        self.record(Observed::Engine(state));
    }
}
