//! Replies with the scripted results in order; unscripted calls get a
//! placeholder transcript so an unrelated scenario keeps flowing.

use std::collections::VecDeque;
use std::sync::{Arc, Mutex};

use calamo_core::dictation::{Language, RawTranscript, Utterance};
use calamo_core::dictionary::DictionaryEntry;
use calamo_core::ports::{TranscriptionError, TranscriptionPort};

use super::Gate;

pub struct TranscriptionCall {
    pub samples: Vec<f32>,
    pub boost_list: Vec<DictionaryEntry>,
}

struct ScriptedReply {
    gate: Option<Arc<Gate>>,
    result: Result<RawTranscript, TranscriptionError>,
}

pub struct ScriptedTranscription {
    script: Mutex<VecDeque<ScriptedReply>>,
    calls: Mutex<Vec<TranscriptionCall>>,
}

impl ScriptedTranscription {
    pub(super) fn new() -> Arc<Self> {
        Arc::new(Self {
            script: Mutex::new(VecDeque::new()),
            calls: Mutex::new(Vec::new()),
        })
    }

    pub fn replies_with(&self, text: &str, language: Language) {
        self.push(None, Ok(RawTranscript::new(text, language)));
    }

    pub fn replies_after(&self, gate: &Arc<Gate>, text: &str, language: Language) {
        self.push(
            Some(Arc::clone(gate)),
            Ok(RawTranscript::new(text, language)),
        );
    }

    pub fn fails(&self, message: &str) {
        self.push(
            None,
            Err(TranscriptionError {
                message: message.to_string(),
            }),
        );
    }

    fn push(&self, gate: Option<Arc<Gate>>, result: Result<RawTranscript, TranscriptionError>) {
        self.script
            .lock()
            .unwrap()
            .push_back(ScriptedReply { gate, result });
    }

    pub fn calls(&self) -> Vec<TranscriptionCall> {
        std::mem::take(&mut *self.calls.lock().unwrap())
    }
}

impl TranscriptionPort for ScriptedTranscription {
    fn transcribe(
        &self,
        utterance: &Utterance,
        boost_list: &[DictionaryEntry],
    ) -> Result<RawTranscript, TranscriptionError> {
        self.calls.lock().unwrap().push(TranscriptionCall {
            samples: utterance.samples().to_vec(),
            boost_list: boost_list.to_vec(),
        });
        let scripted = self.script.lock().unwrap().pop_front();
        match scripted {
            Some(reply) => {
                if let Some(gate) = reply.gate {
                    gate.pass();
                }
                reply.result
            }
            None => Ok(RawTranscript::new(
                "unscripted transcript",
                Language::English,
            )),
        }
    }
}
