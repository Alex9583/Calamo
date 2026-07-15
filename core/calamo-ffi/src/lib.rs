//! calamo-ffi — the UniFFI boundary. Everything Swift sees is exported here;
//! the domain and the adapters never touch the FFI themselves.

// Pins the generated artefact names (calamo.swift, the calamoFFI C module)
// whatever this crate is called.
uniffi::setup_scaffolding!("calamo");

use std::sync::Arc;

/// Build-skeleton stub: its single method returns a marker that traverses
/// the three crates and the FFI. The real facade replaces it.
#[derive(uniffi::Object)]
pub struct DictationEngine;

#[uniffi::export]
impl DictationEngine {
    #[uniffi::constructor]
    pub fn new() -> Arc<Self> {
        Arc::new(Self)
    }

    pub fn build_chain_marker(&self) -> String {
        format!(
            "{} → calamo-ffi {}",
            calamo_adapters::build_chain_marker(),
            env!("CARGO_PKG_VERSION")
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn build_chain_marker_traverses_all_three_crates() {
        let marker = DictationEngine::new().build_chain_marker();
        assert!(marker.contains("calamo-core"));
        assert!(marker.contains("calamo-adapters"));
        assert!(marker.contains("calamo-ffi"));
    }
}
