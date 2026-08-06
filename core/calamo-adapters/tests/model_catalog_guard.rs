//! Always-on guard: the catalog is hand-maintained pin data — a typo'd
//! hash, a branch where a commit belongs, or a stray path must fail here,
//! in CI.

use std::collections::HashSet;

use calamo_adapters::models::catalog::CATALOG;

fn is_lower_hex(s: &str, len: usize) -> bool {
    s.len() == len
        && s.chars()
            .all(|c| c.is_ascii_hexdigit() && !c.is_ascii_uppercase())
}

#[test]
fn given_the_catalog_when_checking_pins_then_revisions_and_digests_are_full_hashes() {
    for model in CATALOG {
        for file in model.files {
            // Then: a 40-hex commit (never a branch), a 64-hex SHA-256, real bytes
            assert!(
                is_lower_hex(model.revision, 40),
                "{}: revision {:?} is not a commit hash",
                model.name,
                model.revision
            );
            assert!(
                is_lower_hex(file.sha256, 64),
                "{}: {} has a malformed SHA-256",
                model.name,
                file.path
            );
            assert!(
                file.size > 0,
                "{}: {} pins zero bytes",
                model.name,
                file.path
            );
        }
    }
}

#[test]
fn given_the_catalog_when_summing_sizes_then_the_pinned_byte_total_holds() {
    // When
    let total: u64 = CATALOG.iter().flat_map(|m| m.files).map(|f| f.size).sum();

    // Then: the byte total measured when the pins were taken
    assert_eq!(total, 1_866_896_478);
}

#[test]
fn given_the_catalog_when_collecting_local_paths_then_they_are_unique_and_rooted() {
    // When
    let locals: Vec<String> = CATALOG
        .iter()
        .flat_map(|m| m.files.iter().map(|f| m.local_path(f)))
        .collect();

    // Then: relative, no traversal, one owner per path
    let mut seen = HashSet::new();
    for local in locals {
        assert!(!local.starts_with('/'), "absolute path {local}");
        assert!(!local.contains(".."), "traversal in {local}");
        assert!(seen.insert(local.clone()), "duplicate path {local}");
    }
}

#[test]
fn given_the_catalog_when_locating_models_then_the_fluidaudio_folder_names_hold() {
    // When
    let folders: Vec<&str> = CATALOG.iter().map(|m| m.folder).collect();

    // Then: FluidAudio resolves models by these exact directory names; the
    // GGUF sits at the store root.
    assert_eq!(
        folders,
        ["parakeet-tdt-0.6b-v3", "parakeet-ctc-110m-coreml", ""]
    );
}
