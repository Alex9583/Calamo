//! Doubles for the five ports and a harness around the facade.

mod cleanup;
mod gate;
mod harness;
mod insertion;
mod observer;
mod repository;
mod transcription;

use std::time::Duration;

pub use cleanup::ScriptedCleanup;
pub use gate::Gate;
pub use harness::Harness;
pub use insertion::RecordingInsertion;
pub use observer::{Observed, RecordingObserver};
pub use repository::StubRepository;
pub use transcription::ScriptedTranscription;

/// Upper bound on any wait for the pipeline thread.
const WAIT: Duration = Duration::from_secs(2);
