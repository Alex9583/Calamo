use calamo_adapters::models::store::ensure;

use crate::support::{InMemoryStorage, RecordingProgress, TEST_CATALOG};

#[test]
fn given_a_store_verified_by_a_previous_run_when_ensure_runs_again_then_nothing_is_rehashed() {
    // Given: a full install left its stamp behind
    let storage = InMemoryStorage::serving(TEST_CATALOG);
    ensure(TEST_CATALOG, &storage, &RecordingProgress::new()).expect("first run");
    storage.calls.borrow_mut().clear();

    // When
    ensure(TEST_CATALOG, &storage, &RecordingProgress::new()).expect("second run");

    // Then: presence and size suffice under the stamp
    assert!(
        storage.digest_calls().is_empty(),
        "{:?}",
        storage.digest_calls()
    );
    assert!(storage.fetch_calls().is_empty());
}

#[test]
fn given_a_touched_file_when_ensure_runs_then_its_bytes_are_rehashed() {
    // Given: same size, fresher mtime — the stamp must not cover it
    let storage = InMemoryStorage::serving(TEST_CATALOG);
    ensure(TEST_CATALOG, &storage, &RecordingProgress::new()).expect("first run");
    storage.calls.borrow_mut().clear();
    let alpha = &TEST_CATALOG[0];
    let one = &alpha.files[0];
    storage.touch(alpha, one);

    // When
    ensure(TEST_CATALOG, &storage, &RecordingProgress::new()).expect("second run");

    // Then: exactly the touched file is rehashed, and its intact bytes stand
    assert_eq!(
        storage.digest_calls(),
        [format!("hash-installed {}", alpha.local_path(one))]
    );
    assert!(storage.fetch_calls().is_empty());
}

#[test]
fn given_a_garbled_stamp_when_ensure_runs_then_every_file_is_rehashed() {
    // Given
    let storage = InMemoryStorage::new();
    storage.install_all(TEST_CATALOG);
    storage.set_stamp("what even is this");

    // When
    ensure(TEST_CATALOG, &storage, &RecordingProgress::new()).expect("ensure");

    // Then: no trust without a well-formed stamp
    assert_eq!(storage.digest_calls().len(), 3);
    assert!(storage.fetch_calls().is_empty());
}

#[test]
fn given_a_truncated_installed_file_when_ensure_runs_then_it_is_replaced_without_hashing() {
    // Given: wrong size — the cheap check must decide alone
    let storage = InMemoryStorage::new();
    storage.install_all(TEST_CATALOG);
    let alpha = &TEST_CATALOG[0];
    let one = &alpha.files[0];
    let path = alpha.local_path(one);
    storage
        .installed
        .borrow_mut()
        .get_mut(&path)
        .expect("seeded")
        .size = one.size - 3;
    storage.serve(alpha, one);

    // When
    ensure(TEST_CATALOG, &storage, &RecordingProgress::new()).expect("ensure");

    // Then: replaced, and its stale bytes were never hashed
    assert_eq!(storage.installed.borrow()[&path].size, one.size);
    assert_eq!(storage.fetch_calls().len(), 1);
    assert!(!storage
        .digest_calls()
        .contains(&format!("hash-installed {path}")));
}

#[test]
fn given_a_corrupt_installed_file_when_ensure_runs_then_it_is_replaced() {
    // Given: right size, wrong bytes
    let storage = InMemoryStorage::new();
    storage.install_all(TEST_CATALOG);
    let alpha = &TEST_CATALOG[0];
    let one = &alpha.files[0];
    storage.install_with_digest(alpha, one, "evil-bytes");
    storage.serve(alpha, one);

    // When
    ensure(TEST_CATALOG, &storage, &RecordingProgress::new()).expect("ensure");

    // Then: only the corrupt file was refetched, and its pin now holds
    assert_eq!(
        storage.installed.borrow()[&alpha.local_path(one)].digest,
        one.sha256
    );
    assert_eq!(
        storage.fetch_calls(),
        [format!(
            "fetch acme/alpha@rev-alpha/one.bin -> {} @0",
            alpha.local_path(one)
        )]
    );
}
