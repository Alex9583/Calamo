use std::collections::HashMap;
use std::fs;

use calamo_adapters::models::catalog::{FileSpec, ModelSpec};
use calamo_adapters::models::disk::DiskModelStorage;
use calamo_adapters::models::store::{ensure, ModelStorage, StoreProgress};

use crate::support::{Route, Server, TempRoot};

fn storage(root: &TempRoot) -> DiskModelStorage {
    DiskModelStorage::with_endpoint(root.path(), "http://127.0.0.1:9")
}

struct NoProgress;

impl StoreProgress for NoProgress {
    fn models_ready(&self, _ready: u32, _total: u32) {}
}

#[test]
fn given_known_bytes_when_hashed_then_the_nist_vector_holds() {
    // Given
    let root = TempRoot::new();
    fs::write(root.path().join("abc.bin"), b"abc").expect("seed");

    // When
    let digest = storage(&root).installed_digest("abc.bin").expect("digest");

    // Then
    assert_eq!(
        digest,
        "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
    );
}

#[test]
fn given_an_absent_file_when_stat_runs_then_meta_is_none_and_partial_len_zero() {
    // Given
    let root = TempRoot::new();

    // When
    let meta = storage(&root).installed_meta("ghost.bin").expect("meta");
    let len = storage(&root).partial_len("ghost.bin").expect("len");

    // Then
    assert!(meta.is_none());
    assert_eq!(len, 0);
}

#[test]
fn given_a_partial_when_promoted_then_it_lands_at_its_final_path() {
    // Given
    let root = TempRoot::new();
    fs::create_dir_all(root.path().join("alpha-dir")).expect("dir");
    fs::write(root.path().join("alpha-dir/one.bin.partial"), b"abc").expect("seed");

    // When
    storage(&root)
        .promote("alpha-dir/one.bin")
        .expect("promote");

    // Then
    assert_eq!(
        fs::read(root.path().join("alpha-dir/one.bin")).expect("installed"),
        b"abc"
    );
    assert!(!root.path().join("alpha-dir/one.bin.partial").exists());
}

#[test]
fn given_a_written_stamp_when_read_back_then_it_is_identical() {
    // Given
    let root = TempRoot::new();

    // When
    storage(&root)
        .write_stamp("calamo-store-v1\n")
        .expect("write");

    // Then
    assert_eq!(
        storage(&root).read_stamp().as_deref(),
        Some("calamo-store-v1\n")
    );
}

const DISK_CATALOG: &[ModelSpec] = &[
    ModelSpec {
        name: "alpha",
        display_name: "Alpha",
        repo: "acme/alpha",
        revision: "rev",
        folder: "alpha-dir",
        files: &[FileSpec {
            path: "one.bin",
            size: 11,
            sha256: "b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9",
        }],
    },
    ModelSpec {
        name: "beta",
        display_name: "Beta",
        repo: "acme/beta",
        revision: "rev",
        folder: "",
        files: &[FileSpec {
            path: "beta.gguf",
            size: 3,
            sha256: "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
        }],
    },
];

#[test]
fn given_a_served_catalog_when_ensure_runs_twice_then_files_land_once_and_stay_trusted() {
    // Given: the store logic driving this adapter end to end
    let root = TempRoot::new();
    let server = Server::start(HashMap::from([
        (
            "/acme/alpha/resolve/rev/one.bin".to_string(),
            Route::RangeAware(b"hello world".to_vec()),
        ),
        (
            "/acme/beta/resolve/rev/beta.gguf".to_string(),
            Route::RangeAware(b"abc".to_vec()),
        ),
    ]));
    let disk = DiskModelStorage::with_endpoint(root.path(), &server.endpoint());

    // When
    ensure(DISK_CATALOG, &disk, &NoProgress).expect("first ensure");
    ensure(DISK_CATALOG, &disk, &NoProgress).expect("second ensure");

    // Then: verified bytes on disk, and the second run never touched the wire
    assert_eq!(
        fs::read(root.path().join("alpha-dir/one.bin")).expect("alpha"),
        b"hello world"
    );
    assert_eq!(
        fs::read(root.path().join("beta.gguf")).expect("beta"),
        b"abc"
    );
    assert_eq!(server.requests().len(), 2);
}
