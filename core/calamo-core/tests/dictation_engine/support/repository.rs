//! Serves whatever dictionary (or load failure) the test primed.

use std::sync::{Arc, Mutex};

use calamo_core::dictionary::Dictionary;
use calamo_core::ports::{DictionaryLoadError, DictionaryRepository};

pub struct StubRepository {
    result: Mutex<Result<Dictionary, DictionaryLoadError>>,
}

impl StubRepository {
    pub(super) fn new() -> Arc<Self> {
        Arc::new(Self {
            result: Mutex::new(Ok(Dictionary::new(Vec::new()).unwrap())),
        })
    }

    pub fn holds(&self, dictionary: Dictionary) {
        *self.result.lock().unwrap() = Ok(dictionary);
    }

    pub fn fails(&self, message: &str) {
        *self.result.lock().unwrap() = Err(DictionaryLoadError {
            message: message.to_string(),
        });
    }
}

impl DictionaryRepository for StubRepository {
    fn load(&self) -> Result<Dictionary, DictionaryLoadError> {
        self.result.lock().unwrap().clone()
    }
}
