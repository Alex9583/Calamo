//! Mechanical translation between the core's domain types and their mirrors.

use calamo_core::dictation as core_dictation;
use calamo_core::engine as core_engine;

use crate::types::{
    CaptureIncident, DictationState, EngineState, FailureReason, Language, RefusalCause,
    UnavailabilityCause,
};

impl From<Language> for core_dictation::Language {
    fn from(language: Language) -> Self {
        match language {
            Language::French => Self::French,
            Language::English => Self::English,
        }
    }
}

impl From<core_dictation::DictationState> for DictationState {
    fn from(state: core_dictation::DictationState) -> Self {
        use core_dictation::DictationState as Core;
        match state {
            Core::Capturing => Self::Capturing,
            Core::Transcribing => Self::Transcribing,
            Core::Cleaning => Self::Cleaning,
            Core::Inserting => Self::Inserting,
            Core::Completed { degraded } => Self::Completed { degraded },
            Core::Failed { reason } => Self::Failed {
                reason: reason.into(),
            },
        }
    }
}

impl From<core_dictation::FailureReason> for FailureReason {
    fn from(reason: core_dictation::FailureReason) -> Self {
        use core_dictation::FailureReason as Core;
        match reason {
            Core::EmptyDictation => Self::EmptyDictation,
            Core::SecureField => Self::SecureField,
            Core::TranscriptionFailed => Self::TranscriptionFailed,
            Core::InsertionFailed => Self::InsertionFailed,
            Core::MicUnavailable => Self::MicUnavailable,
            Core::PermissionRevoked => Self::PermissionRevoked,
        }
    }
}

impl From<core_engine::EngineState> for EngineState {
    fn from(state: core_engine::EngineState) -> Self {
        use core_engine::EngineState as Core;
        match state {
            Core::Loading => Self::Loading,
            Core::Ready => Self::Ready,
            Core::Unavailable { cause } => Self::Unavailable {
                cause: cause.into(),
            },
        }
    }
}

impl From<core_engine::UnavailabilityCause> for UnavailabilityCause {
    fn from(cause: core_engine::UnavailabilityCause) -> Self {
        match cause {
            core_engine::UnavailabilityCause::ModelsMissing => Self::ModelsMissing,
        }
    }
}

impl From<UnavailabilityCause> for core_engine::UnavailabilityCause {
    fn from(cause: UnavailabilityCause) -> Self {
        match cause {
            UnavailabilityCause::ModelsMissing => Self::ModelsMissing,
        }
    }
}

impl From<core_engine::RefusalCause> for RefusalCause {
    fn from(cause: core_engine::RefusalCause) -> Self {
        use core_engine::RefusalCause as Core;
        match cause {
            Core::EngineLoading => Self::EngineLoading,
            Core::EngineUnavailable { cause } => Self::EngineUnavailable {
                cause: cause.into(),
            },
            Core::PipelineBusy => Self::PipelineBusy,
        }
    }
}

impl From<CaptureIncident> for core_engine::CaptureIncident {
    fn from(incident: CaptureIncident) -> Self {
        match incident {
            CaptureIncident::MicUnavailable => Self::MicUnavailable,
            CaptureIncident::PermissionRevoked => Self::PermissionRevoked,
        }
    }
}
