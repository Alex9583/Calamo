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
