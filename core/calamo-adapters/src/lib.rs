//! calamo-adapters — Rust-side adapters of the core's internal ports.

/// Build-skeleton marker proving the domain → adapters link;
/// deleted once real adapters land.
pub fn build_chain_marker() -> String {
    format!(
        "{} → calamo-adapters {}",
        calamo_core::build_chain_marker(),
        env!("CARGO_PKG_VERSION")
    )
}
