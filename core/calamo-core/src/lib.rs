//! calamo-core — the pure domain crate. It owns the whole domain and the
//! pipeline orchestration; it never touches I/O, models, or the FFI.

/// Build-skeleton marker proving this crate is linked into the chain;
/// deleted once the real domain lands.
pub fn build_chain_marker() -> String {
    concat!("calamo-core ", env!("CARGO_PKG_VERSION")).to_string()
}
