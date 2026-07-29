//! The pipeline thread: one Dictation at a time through transcription →
//! cleanup → insertion.

use std::sync::mpsc::Receiver;
use std::sync::{Arc, Weak};
use std::thread;

use crate::dictation::{
    CleanedText, DictationId, DictationState, FailureReason, RawTranscript, Utterance,
};
use crate::dictionary::Dictionary;
use crate::ports::{
    CleanupPort, DictationObserver, InsertionError, InsertionPort, TranscriptionPort,
};
use crate::spelling_enforcement;

use super::Shared;

/// A released Dictation with its Dictionary snapshot — a reload never
/// changes a dictation in flight.
pub(super) struct Job {
    pub(super) id: DictationId,
    pub(super) utterance: Utterance,
    pub(super) dictionary: Arc<Dictionary>,
}

/// One core thread processes jobs in dispatch order — insertions land in
/// release order by construction. Ends when the engine (only sender) drops.
pub(super) fn spawn(
    job_rx: Receiver<Job>,
    shared: Weak<Shared>,
    transcription: Arc<dyn TranscriptionPort>,
    cleanup: Arc<dyn CleanupPort>,
    insertion: Arc<dyn InsertionPort>,
    observer: Arc<dyn DictationObserver>,
) -> thread::JoinHandle<()> {
    let pipeline = Pipeline {
        transcription,
        cleanup,
        insertion,
        observer,
    };
    thread::spawn(move || {
        while let Ok(job) = job_rx.recv() {
            pipeline.process(&job);
            let Some(shared) = shared.upgrade() else {
                break;
            };
            shared.finish_job_and_dispatch_next();
        }
    })
}

impl Shared {
    /// Dispatches the capture that was released while the pipeline was busy.
    fn finish_job_and_dispatch_next(&self) {
        let next = {
            let mut state = self.state.lock().unwrap();
            match &state.capture {
                Some(waiting) if waiting.closed => Some(state.dispatch_capture()),
                _ => {
                    state.pipeline_busy = false;
                    None
                }
            }
        };
        if let Some(job) = next {
            let _ = self.job_tx.send(job);
        }
    }
}

struct Pipeline {
    transcription: Arc<dyn TranscriptionPort>,
    cleanup: Arc<dyn CleanupPort>,
    insertion: Arc<dyn InsertionPort>,
    observer: Arc<dyn DictationObserver>,
}

impl Pipeline {
    fn process(&self, job: &Job) {
        let terminal = self.run(job);
        self.report(job, terminal);
    }

    fn run(&self, job: &Job) -> DictationState {
        let transcript = match self.transcribe(job) {
            Ok(transcript) => transcript,
            Err(reason) => return DictationState::Failed { reason },
        };
        let (cleaned, degraded) = self.clean(job, &transcript);
        match self.insert(job, &cleaned) {
            Ok(()) => DictationState::Completed { degraded },
            Err(reason) => DictationState::Failed { reason },
        }
    }

    fn transcribe(&self, job: &Job) -> Result<RawTranscript, FailureReason> {
        self.report(job, DictationState::Transcribing);
        let transcript = self
            .transcription
            .transcribe(&job.utterance, job.dictionary.boost_list())
            .map_err(|_| FailureReason::TranscriptionFailed)?;
        if transcript.text().trim().is_empty() {
            return Err(FailureReason::EmptyDictation);
        }
        Ok(transcript)
    }

    /// Cleanup failure is never fatal: degrade to the verbatim transcript.
    fn clean(&self, job: &Job, transcript: &RawTranscript) -> (String, bool) {
        self.report(job, DictationState::Cleaning);
        let glossary = job.dictionary.prompt_glossary(transcript.text());
        match self.cleanup.clean(transcript, &glossary) {
            Ok(cleaned) => (cleaned, false),
            Err(_) => (transcript.text().to_string(), true),
        }
    }

    fn insert(&self, job: &Job, cleaned: &str) -> Result<(), FailureReason> {
        self.report(job, DictationState::Inserting);
        let text = CleanedText::new(spelling_enforcement::enforce(cleaned, &job.dictionary));
        self.insertion.insert(&text).map_err(|e| match e {
            InsertionError::SecureField => FailureReason::SecureField,
            InsertionError::Failed { .. } => FailureReason::InsertionFailed,
        })
    }

    fn report(&self, job: &Job, state: DictationState) {
        self.observer.dictation_state_changed(job.id, state);
    }
}
