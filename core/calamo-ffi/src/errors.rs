//! Port errors crossing the boundary; an unexpected Swift exception lands in
//! the Failed variant.

use std::fmt;

#[derive(Debug, Clone, PartialEq, uniffi::Error)]
pub enum TranscriptionError {
    Failed { message: String },
}

impl fmt::Display for TranscriptionError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Failed { message } => write!(f, "transcription failed: {message}"),
        }
    }
}

impl std::error::Error for TranscriptionError {}

impl From<uniffi::UnexpectedUniFFICallbackError> for TranscriptionError {
    fn from(error: uniffi::UnexpectedUniFFICallbackError) -> Self {
        Self::Failed {
            message: error.reason,
        }
    }
}

/// The previous dictionary stayed active; line and cause feed the shell's
/// notification.
#[derive(Debug, Clone, PartialEq, uniffi::Error)]
pub enum DictionaryLoadError {
    Invalid { line: Option<u32>, message: String },
}

impl fmt::Display for DictionaryLoadError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Invalid {
                line: Some(line),
                message,
            } => write!(f, "invalid dictionary: line {line}: {message}"),
            Self::Invalid {
                line: None,
                message,
            } => write!(f, "invalid dictionary: {message}"),
        }
    }
}

impl std::error::Error for DictionaryLoadError {}

#[derive(Debug, Clone, PartialEq, uniffi::Error)]
pub enum CleanupLoadError {
    Failed { message: String },
}

impl fmt::Display for CleanupLoadError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Failed { message } => write!(f, "cleanup load failed: {message}"),
        }
    }
}

impl std::error::Error for CleanupLoadError {}

#[derive(Debug, Clone, PartialEq, uniffi::Error)]
pub enum InsertionError {
    SecureField,
    Failed { message: String },
}

impl fmt::Display for InsertionError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::SecureField => write!(f, "insertion refused: secure field"),
            Self::Failed { message } => write!(f, "insertion failed: {message}"),
        }
    }
}

impl std::error::Error for InsertionError {}

impl From<uniffi::UnexpectedUniFFICallbackError> for InsertionError {
    fn from(error: uniffi::UnexpectedUniFFICallbackError) -> Self {
        Self::Failed {
            message: error.reason,
        }
    }
}
