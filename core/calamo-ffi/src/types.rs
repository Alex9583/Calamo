//! Records and enums crossing the boundary, mirrored field for field from
//! the core so the domain stays free of FFI concerns.

#[derive(Debug, Clone, PartialEq, uniffi::Enum)]
pub enum Language {
    French,
    English,
}

#[derive(Debug, Clone, PartialEq, uniffi::Record)]
pub struct RawTranscript {
    pub text: String,
    pub language: Language,
}

/// One Dictionary entry handed to speech recognition for boosting.
#[derive(Debug, Clone, PartialEq, uniffi::Record)]
pub struct BoostEntry {
    pub canonical_text: String,
    pub aliases: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, uniffi::Enum)]
pub enum DictationState {
    Capturing,
    Transcribing,
    Cleaning,
    Inserting,
    Completed { degraded: bool },
    Failed { reason: FailureReason },
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Enum)]
pub enum FailureReason {
    EmptyDictation,
    SecureField,
    TranscriptionFailed,
    InsertionFailed,
    MicUnavailable,
    PermissionRevoked,
}

#[derive(Debug, Clone, PartialEq, uniffi::Enum)]
pub enum EngineState {
    Loading,
    Ready,
    Unavailable { cause: UnavailabilityCause },
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Enum)]
pub enum UnavailabilityCause {
    ModelsMissing,
}

#[derive(Debug, Clone, PartialEq, uniffi::Enum)]
pub enum RefusalCause {
    EngineLoading,
    EngineUnavailable { cause: UnavailabilityCause },
    PipelineBusy,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Enum)]
pub enum CaptureIncident {
    MicUnavailable,
    PermissionRevoked,
}

#[derive(Debug, Clone, PartialEq, uniffi::Record)]
pub struct EngineConfig {
    pub dictionary_path: String,
    pub cleanup_model_path: String,
}
