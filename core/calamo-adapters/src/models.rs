//! The ModelStore: installs the pinned model catalog at its definitive
//! location, verifies it byte-for-byte, resumes interrupted downloads.

pub mod catalog;
pub mod disk;
mod stamp;
pub mod store;
