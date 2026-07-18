//! Records every inserted text; refusals are scripted, in order.

use std::collections::VecDeque;
use std::sync::{Arc, Mutex};

use calamo_core::dictation::CleanedText;
use calamo_core::ports::{InsertionError, InsertionPort};

pub struct RecordingInsertion {
    script: Mutex<VecDeque<Result<(), InsertionError>>>,
    texts: Mutex<Vec<String>>,
}

impl RecordingInsertion {
    pub(super) fn new() -> Arc<Self> {
        Arc::new(Self {
            script: Mutex::new(VecDeque::new()),
            texts: Mutex::new(Vec::new()),
        })
    }

    pub fn refuses_secure_field(&self) {
        self.script
            .lock()
            .unwrap()
            .push_back(Err(InsertionError::SecureField));
    }

    pub fn fails(&self, message: &str) {
        self.script
            .lock()
            .unwrap()
            .push_back(Err(InsertionError::Failed {
                message: message.to_string(),
            }));
    }

    pub fn inserted_texts(&self) -> Vec<String> {
        self.texts.lock().unwrap().clone()
    }
}

impl InsertionPort for RecordingInsertion {
    fn insert(&self, text: &CleanedText) -> Result<(), InsertionError> {
        let outcome = self.script.lock().unwrap().pop_front().unwrap_or(Ok(()));
        if outcome.is_ok() {
            self.texts.lock().unwrap().push(text.as_str().to_string());
        }
        outcome
    }
}
