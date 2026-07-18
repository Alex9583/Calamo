//! The DictationEngine facade — the seam UniFFI exports: Dictation
//! lifecycle, pipeline orchestration, refusal rules.

mod pipeline;

use std::sync::mpsc::{self, Sender};
use std::sync::{Arc, Mutex};

use crate::dictation::{DictationId, DictationState, FailureReason, Utterance};
use crate::dictionary::Dictionary;
use crate::ports::{
    CleanupPort, DictationObserver, DictionaryRepository, InsertionPort, TranscriptionPort,
};
use pipeline::Job;

/// The runtime state gating dictation: no Dictation is born outside Ready.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum EngineState {
    Loading,
    Ready,
    Unavailable { cause: UnavailabilityCause },
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum UnavailabilityCause {
    ModelsMissing,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum RefusalCause {
    EngineLoading,
    EngineUnavailable { cause: UnavailabilityCause },
    /// One Dictation processing + one waiting captured: refused, never queued.
    PipelineBusy,
}

/// Reported by the shell while a capture is in progress.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CaptureIncident {
    MicUnavailable,
    PermissionRevoked,
}

pub struct DictationEngine {
    shared: Arc<Shared>,
    repository: Arc<dyn DictionaryRepository>,
}

struct Shared {
    observer: Arc<dyn DictationObserver>,
    job_tx: Sender<Job>,
    state: Mutex<State>,
}

/// Locked for bookkeeping only — ports and observer are called outside it.
struct State {
    availability: EngineState,
    dictionary: Arc<Dictionary>,
    capture: Option<Capture>,
    /// At most one job on the pipeline thread.
    pipeline_busy: bool,
    next_id: u64,
}

/// The Dictation holding the capture slot. Closed: released while the
/// pipeline was busy — it waits in the slot until the pipeline frees up.
struct Capture {
    id: DictationId,
    samples: Vec<f32>,
    closed: bool,
}

enum PressOutcome {
    Started(DictationId),
    Refused(RefusalCause),
    /// Key repeat: the capture in progress continues.
    Ignored,
}

enum ReleaseOutcome {
    /// No capture, or already released.
    Inert,
    Empty(DictationId),
    Dispatch(Job),
    /// Pipeline busy: the closed capture waits in its slot.
    Waiting,
}

impl DictationEngine {
    pub fn new(
        transcription: Arc<dyn TranscriptionPort>,
        cleanup: Arc<dyn CleanupPort>,
        insertion: Arc<dyn InsertionPort>,
        observer: Arc<dyn DictationObserver>,
        repository: Arc<dyn DictionaryRepository>,
    ) -> Self {
        let dictionary = repository
            .load()
            .unwrap_or_else(|_| Dictionary::new(Vec::new()).expect("empty dictionary is valid"));
        let (job_tx, job_rx) = mpsc::channel();
        let shared = Arc::new(Shared {
            observer: Arc::clone(&observer),
            job_tx,
            state: Mutex::new(State {
                availability: EngineState::Loading,
                dictionary: Arc::new(dictionary),
                capture: None,
                pipeline_busy: false,
                next_id: 1,
            }),
        });
        pipeline::spawn(
            job_rx,
            Arc::downgrade(&shared),
            transcription,
            cleanup,
            insertion,
            observer,
        );
        Self { shared, repository }
    }

    pub fn hotkey_pressed(&self) {
        let outcome = self.shared.state.lock().unwrap().press();
        self.shared.apply_press(outcome);
    }

    pub fn hotkey_released(&self) {
        let outcome = self.shared.state.lock().unwrap().release_capture();
        self.shared.apply_release(outcome);
    }

    pub fn push_audio(&self, samples: &[f32]) {
        let mut state = self.shared.state.lock().unwrap();
        // Frames after release or refusal belong to no Utterance: dropped.
        if let Some(capture) = &mut state.capture {
            if !capture.closed {
                capture.samples.extend_from_slice(samples);
            }
        }
    }

    /// On failure the previous dictionary stays active — an invalid file
    /// never breaks dictation.
    pub fn reload_dictionary(&self) {
        if let Ok(dictionary) = self.repository.load() {
            self.shared.state.lock().unwrap().dictionary = Arc::new(dictionary);
        }
    }

    /// Fails the capturing Dictation; the release that follows finds no
    /// capture and stays inert.
    pub fn capture_failed(&self, incident: CaptureIncident) {
        let failed = {
            let mut state = self.shared.state.lock().unwrap();
            // A closed capture already has its complete Utterance: unaffected.
            match &state.capture {
                Some(open) if !open.closed => state.capture.take(),
                _ => None,
            }
        };
        if let Some(capture) = failed {
            let reason = match incident {
                CaptureIncident::MicUnavailable => FailureReason::MicUnavailable,
                CaptureIncident::PermissionRevoked => FailureReason::PermissionRevoked,
            };
            self.shared
                .observer
                .dictation_state_changed(capture.id, DictationState::Failed { reason });
        }
    }

    pub fn mark_ready(&self) {
        self.set_availability(EngineState::Ready);
    }

    pub fn mark_loading(&self) {
        self.set_availability(EngineState::Loading);
    }

    pub fn mark_unavailable(&self, cause: UnavailabilityCause) {
        self.set_availability(EngineState::Unavailable { cause });
    }

    fn set_availability(&self, availability: EngineState) {
        let changed = {
            let mut state = self.shared.state.lock().unwrap();
            let changed = state.availability != availability;
            state.availability = availability.clone();
            changed
        };
        if changed {
            self.shared.observer.engine_state_changed(availability);
        }
    }
}

impl State {
    fn press(&mut self) -> PressOutcome {
        match self.availability {
            EngineState::Loading => PressOutcome::Refused(RefusalCause::EngineLoading),
            EngineState::Unavailable { cause } => {
                PressOutcome::Refused(RefusalCause::EngineUnavailable { cause })
            }
            EngineState::Ready => match &self.capture {
                Some(open) if !open.closed => PressOutcome::Ignored,
                Some(_waiting) => PressOutcome::Refused(RefusalCause::PipelineBusy),
                None => PressOutcome::Started(self.start_capture()),
            },
        }
    }

    fn start_capture(&mut self) -> DictationId {
        let id = DictationId(self.next_id);
        self.next_id += 1;
        self.capture = Some(Capture {
            id,
            samples: Vec::new(),
            closed: false,
        });
        id
    }

    fn release_capture(&mut self) -> ReleaseOutcome {
        let pipeline_busy = self.pipeline_busy;
        match &mut self.capture {
            Some(open) if !open.closed => {
                if open.samples.is_empty() {
                    let id = open.id;
                    self.capture = None;
                    ReleaseOutcome::Empty(id)
                } else if pipeline_busy {
                    open.closed = true;
                    ReleaseOutcome::Waiting
                } else {
                    ReleaseOutcome::Dispatch(self.dispatch_capture())
                }
            }
            _ => ReleaseOutcome::Inert,
        }
    }

    /// Takes the capture as the pipeline's next Job; the caller sends it.
    fn dispatch_capture(&mut self) -> Job {
        self.pipeline_busy = true;
        let capture = self.capture.take().expect("a capture to dispatch");
        Job {
            id: capture.id,
            utterance: Utterance::new(capture.samples),
            dictionary: Arc::clone(&self.dictionary),
        }
    }
}

/// Effects of the decisions made under the lock, run outside it.
impl Shared {
    fn apply_press(&self, outcome: PressOutcome) {
        match outcome {
            PressOutcome::Started(id) => self
                .observer
                .dictation_state_changed(id, DictationState::Capturing),
            PressOutcome::Refused(cause) => self.observer.dictation_refused(cause),
            PressOutcome::Ignored => {}
        }
    }

    fn apply_release(&self, outcome: ReleaseOutcome) {
        match outcome {
            ReleaseOutcome::Empty(id) => self.observer.dictation_state_changed(
                id,
                DictationState::Failed {
                    reason: FailureReason::EmptyDictation,
                },
            ),
            ReleaseOutcome::Dispatch(job) => {
                let _ = self.job_tx.send(job);
            }
            ReleaseOutcome::Inert | ReleaseOutcome::Waiting => {}
        }
    }
}

