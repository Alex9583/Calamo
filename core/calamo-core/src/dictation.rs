//! The Dictation aggregate's observable vocabulary: one push-to-talk
//! interaction, from hotkey press to text insertion, and its value objects.

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct DictationId(pub u64);

/// The cycle a Dictation moves through:
/// `Capturing → Transcribing → Cleaning → Inserting → Completed | Failed`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum DictationState {
    Capturing,
    Transcribing,
    Cleaning,
    Inserting,
    /// Degraded — cleanup failed, the enforced verbatim was inserted — is
    /// still Completed, never Failed.
    Completed { degraded: bool },
    Failed { reason: FailureReason },
}

/// Every way a Dictation can end without inserting — never a silent failure.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FailureReason {
    EmptyDictation,
    SecureField,
    TranscriptionFailed,
    InsertionFailed,
    MicUnavailable,
    PermissionRevoked,
}

/// Mono 16 kHz f32 audio captured between hotkey press and release.
#[derive(Debug, Clone, PartialEq)]
pub struct Utterance {
    samples: Vec<f32>,
}

impl Utterance {
    pub(crate) fn new(samples: Vec<f32>) -> Self {
        Self { samples }
    }

    pub fn samples(&self) -> &[f32] {
        &self.samples
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Language {
    French,
    English,
}

/// Speech-recognition output before any cleanup, with its detected language.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RawTranscript {
    text: String,
    language: Language,
}

impl RawTranscript {
    pub fn new(text: impl Into<String>, language: Language) -> Self {
        Self {
            text: text.into(),
            language,
        }
    }

    pub fn text(&self) -> &str {
        &self.text
    }

    pub fn language(&self) -> Language {
        self.language
    }
}

/// The final text ready for insertion, dictionary spellings enforced.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CleanedText {
    text: String,
}

impl CleanedText {
    pub(crate) fn new(text: String) -> Self {
        Self { text }
    }

    pub fn as_str(&self) -> &str {
        &self.text
    }
}
