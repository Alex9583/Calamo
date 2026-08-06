use calamo_adapters::models::store::{ensure, StoreError};

use crate::support::{InMemoryStorage, RecordingProgress, TEST_CATALOG};

fn storage_with_everything_but_alpha_one() -> InMemoryStorage {
    let storage = InMemoryStorage::new();
    storage.install_all(TEST_CATALOG);
    storage
        .installed
        .borrow_mut()
        .remove(&TEST_CATALOG[0].local_path(&TEST_CATALOG[0].files[0]));
    storage
}

#[test]
fn given_a_corrupt_download_when_ensure_runs_then_one_fresh_refetch_recovers() {
    // Given: the remote serves bad bytes once, then good ones
    let storage = storage_with_everything_but_alpha_one();
    let alpha = &TEST_CATALOG[0];
    let one = &alpha.files[0];
    storage.serve_corrupt(alpha, one);
    storage.serve(alpha, one);

    // When
    ensure(TEST_CATALOG, &storage, &RecordingProgress::new()).expect("ensure");

    // Then: discarded and refetched from scratch, then installed
    let path = alpha.local_path(one);
    assert_eq!(storage.installed.borrow()[&path].digest, one.sha256);
    assert_eq!(
        storage.fetch_calls(),
        [
            format!("fetch acme/alpha@rev-alpha/one.bin -> {path} @0"),
            format!("fetch acme/alpha@rev-alpha/one.bin -> {path} @0"),
        ]
    );
}

#[test]
fn given_a_persistently_corrupt_download_when_ensure_runs_then_it_fails_as_corrupted() {
    // Given
    let storage = storage_with_everything_but_alpha_one();
    let alpha = &TEST_CATALOG[0];
    let one = &alpha.files[0];
    storage.serve_corrupt(alpha, one);
    storage.serve_corrupt(alpha, one);

    // When
    let outcome = ensure(TEST_CATALOG, &storage, &RecordingProgress::new());

    // Then: named cause, and no unverified bytes left installed
    let path = alpha.local_path(one);
    assert!(matches!(outcome, Err(StoreError::Corrupted { path: p }) if p == path));
    assert!(!storage.installed.borrow().contains_key(&path));
    assert!(!storage.partials.borrow().contains_key(&path));
}

#[test]
fn given_a_network_failure_when_ensure_runs_then_it_fails_as_download_and_keeps_the_partial() {
    // Given: 4 bytes down, then the connection dies
    let storage = storage_with_everything_but_alpha_one();
    let alpha = &TEST_CATALOG[0];
    let one = &alpha.files[0];
    storage.leave_partial(alpha, one, 4, "mid-download");
    storage.serve_failure(alpha, one, "connection reset");

    // When
    let outcome = ensure(TEST_CATALOG, &storage, &RecordingProgress::new());

    // Then: the error carries the cause and the partial survives for resume
    match outcome {
        Err(StoreError::Download { path, message }) => {
            assert_eq!(path, alpha.local_path(one));
            assert_eq!(message, "connection reset");
        }
        other => panic!("expected Download error, got {other:?}"),
    }
    assert_eq!(
        storage.partials.borrow()[&alpha.local_path(one)].len,
        4,
        "the partial must survive for the next resume"
    );
}

#[test]
fn given_a_complete_partial_when_ensure_runs_then_it_is_promoted_without_fetching() {
    // Given: the interruption hit between download and install
    let storage = storage_with_everything_but_alpha_one();
    let alpha = &TEST_CATALOG[0];
    let one = &alpha.files[0];
    storage.leave_partial(alpha, one, one.size, one.sha256);

    // When
    ensure(TEST_CATALOG, &storage, &RecordingProgress::new()).expect("ensure");

    // Then
    assert!(storage.fetch_calls().is_empty());
    assert_eq!(
        storage.installed.borrow()[&alpha.local_path(one)].digest,
        one.sha256
    );
}

#[test]
fn given_an_oversized_partial_when_ensure_runs_then_it_is_discarded_and_refetched() {
    // Given: more bytes than the pin — resuming could never verify
    let storage = storage_with_everything_but_alpha_one();
    let alpha = &TEST_CATALOG[0];
    let one = &alpha.files[0];
    storage.leave_partial(alpha, one, one.size + 7, "garbage");
    storage.serve(alpha, one);

    // When
    ensure(TEST_CATALOG, &storage, &RecordingProgress::new()).expect("ensure");

    // Then
    let path = alpha.local_path(one);
    let about_one: Vec<String> = storage
        .calls()
        .into_iter()
        .filter(|c| c.ends_with(&format!(" {path}")) || c.contains(&format!("-> {path} ")))
        .collect();
    assert_eq!(
        about_one,
        [
            format!("discard {path}"),
            format!("fetch acme/alpha@rev-alpha/one.bin -> {path} @0"),
            format!("hash-partial {path}"),
            format!("promote {path}"),
        ]
    );
}

#[test]
fn given_an_interrupted_download_when_ensure_runs_then_the_fetch_resumes_where_it_stopped() {
    // Given: 4 of 10 bytes already on disk
    let storage = storage_with_everything_but_alpha_one();
    let alpha = &TEST_CATALOG[0];
    let one = &alpha.files[0];
    storage.leave_partial(alpha, one, 4, "mid-download");
    storage.serve(alpha, one);

    // When
    ensure(TEST_CATALOG, &storage, &RecordingProgress::new()).expect("ensure");

    // Then
    let path = alpha.local_path(one);
    assert_eq!(
        storage.fetch_calls(),
        [format!("fetch acme/alpha@rev-alpha/one.bin -> {path} @4")]
    );
    assert_eq!(storage.installed.borrow()[&path].digest, one.sha256);
}
