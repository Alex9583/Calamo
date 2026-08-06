use calamo_adapters::models::store::ensure;

use crate::support::{InMemoryStorage, RecordingProgress, TEST_CATALOG};

#[test]
fn given_a_cold_install_when_models_complete_then_progress_counts_them() {
    // Given
    let storage = InMemoryStorage::serving(TEST_CATALOG);
    let progress = RecordingProgress::new();

    // When
    ensure(TEST_CATALOG, &storage, &progress).expect("ensure");

    // Then: an opening count, then one per completed model
    assert_eq!(progress.events(), [(0, 2), (1, 2), (2, 2)]);
}

#[test]
fn given_one_model_missing_when_ensure_runs_then_progress_opens_at_the_ready_count() {
    // Given: alpha installed and intact, beta gone
    let storage = InMemoryStorage::new();
    let alpha = &TEST_CATALOG[0];
    for file in alpha.files {
        storage.install(alpha, file);
    }
    let beta = &TEST_CATALOG[1];
    storage.serve(beta, &beta.files[0]);

    // When
    let progress = RecordingProgress::new();
    ensure(TEST_CATALOG, &storage, &progress).expect("ensure");

    // Then
    assert_eq!(progress.events(), [(1, 2), (2, 2)]);
}

#[test]
fn given_a_complete_store_when_ensure_runs_then_no_progress_is_reported() {
    // Given
    let storage = InMemoryStorage::new();
    storage.install_all(TEST_CATALOG);

    // When
    let progress = RecordingProgress::new();
    ensure(TEST_CATALOG, &storage, &progress).expect("ensure");

    // Then: the fast path is silent
    assert_eq!(progress.events(), []);
}

#[test]
fn given_an_empty_store_when_ensure_runs_then_every_file_is_downloaded_verified_and_installed() {
    // Given
    let storage = InMemoryStorage::serving(TEST_CATALOG);
    let progress = RecordingProgress::new();

    // When
    ensure(TEST_CATALOG, &storage, &progress).expect("ensure");

    // Then: every catalog file installed with its pinned digest, no leftovers
    let installed = storage.installed.borrow();
    for model in TEST_CATALOG {
        for file in model.files {
            let entry = &installed[&model.local_path(file)];
            assert_eq!(entry.digest, file.sha256);
            assert_eq!(entry.size, file.size);
        }
    }
    assert!(storage.partials.borrow().is_empty());
}
