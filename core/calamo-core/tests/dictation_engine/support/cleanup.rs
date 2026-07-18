//! Replies with the scripted results in order; unscripted calls echo the
//! transcript (a cleanup that changes nothing).

use std::collections::VecDeque;
use std::sync::{Arc, Mutex};

use calamo_core::dictation::RawTranscript;
use calamo_core::ports::{CleanupError, CleanupPort};

pub struct CleanupCall {
    pub transcript: String,
    pub glossary: Vec<String>,
}

pub struct ScriptedCleanup {
    script: Mutex<VecDeque<Result<String, CleanupError>>>,
    calls: Mutex<Vec<CleanupCall>>,
}

impl ScriptedCleanup {
    pub(super) fn new() -> Arc<Self> {
        Arc::new(Self {
            script: Mutex::new(VecDeque::new()),
            calls: Mutex::new(Vec::new()),
        })
    }

    pub fn replies_with(&self, text: &str) {
        self.script.lock().unwrap().push_back(Ok(text.to_string()));
    }

    pub fn fails(&self, message: &str) {
        self.script.lock().unwrap().push_back(Err(CleanupError {
            message: message.to_string(),
        }));
    }

    pub fn calls(&self) -> Vec<CleanupCall> {
        std::mem::take(&mut *self.calls.lock().unwrap())
    }
}

impl CleanupPort for ScriptedCleanup {
    fn clean(&self, transcript: &RawTranscript, glossary: &[&str]) -> Result<String, CleanupError> {
        self.calls.lock().unwrap().push(CleanupCall {
            transcript: transcript.text().to_string(),
            glossary: glossary.iter().map(|s| s.to_string()).collect(),
        });
        let scripted = self.script.lock().unwrap().pop_front();
        scripted.unwrap_or_else(|| Ok(transcript.text().to_string()))
    }
}
