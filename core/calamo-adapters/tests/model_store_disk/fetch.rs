use std::collections::HashMap;
use std::fs;

use calamo_adapters::models::disk::DiskModelStorage;
use calamo_adapters::models::store::{ModelStorage, RemoteFile};

use crate::support::{Route, Server, TempRoot};

const ONE_BIN: &str = "/acme/alpha/resolve/rev/one.bin";

fn remote() -> RemoteFile<'static> {
    RemoteFile {
        repo: "acme/alpha",
        revision: "rev",
        path: "one.bin",
    }
}

fn server_with(route: Route) -> Server {
    Server::start(HashMap::from([(ONE_BIN.to_string(), route)]))
}

fn seed_partial(root: &TempRoot, bytes: &[u8]) {
    fs::create_dir_all(root.path().join("alpha-dir")).expect("dir");
    fs::write(root.path().join("alpha-dir/one.bin.partial"), bytes).expect("seed");
}

fn partial(root: &TempRoot) -> Vec<u8> {
    fs::read(root.path().join("alpha-dir/one.bin.partial")).expect("partial")
}

#[test]
fn given_a_fresh_root_when_fetch_runs_then_bounded_chunks_assemble_the_body() {
    // Given: an 11-byte body walked in 4-byte chunks
    let root = TempRoot::new();
    let server = server_with(Route::RangeAware(b"hello world".to_vec()));
    let storage = DiskModelStorage::with_endpoint(root.path(), &server.endpoint()).chunked(4);

    // When
    storage
        .fetch(&remote(), "alpha-dir/one.bin", 0)
        .expect("fetch");

    // Then: assembled in the partial, nothing installed, every chunk bounded
    assert_eq!(partial(&root), b"hello world");
    assert!(!root.path().join("alpha-dir/one.bin").exists());
    assert_eq!(
        server.requests(),
        [
            format!("GET {ONE_BIN} range=bytes=0-3"),
            format!("GET {ONE_BIN} range=bytes=4-7"),
            format!("GET {ONE_BIN} range=bytes=8-11"),
        ]
    );
}

#[test]
fn given_a_partial_when_fetch_resumes_then_the_ranged_tail_is_appended() {
    // Given: the first 5 bytes already on disk
    let root = TempRoot::new();
    let server = server_with(Route::RangeAware(b"hello world".to_vec()));
    let storage = DiskModelStorage::with_endpoint(root.path(), &server.endpoint()).chunked(4);
    seed_partial(&root, b"hello");

    // When
    storage
        .fetch(&remote(), "alpha-dir/one.bin", 5)
        .expect("fetch");

    // Then
    assert_eq!(partial(&root), b"hello world");
    assert_eq!(
        server.requests(),
        [
            format!("GET {ONE_BIN} range=bytes=5-8"),
            format!("GET {ONE_BIN} range=bytes=9-12"),
        ]
    );
}

#[test]
fn given_a_body_ending_on_a_chunk_boundary_when_fetching_then_the_416_closes_the_loop() {
    // Given: 8 bytes, 4-byte chunks — the last chunk lands exactly on the end
    let root = TempRoot::new();
    let server = server_with(Route::RangeAware(b"12345678".to_vec()));
    let storage = DiskModelStorage::with_endpoint(root.path(), &server.endpoint()).chunked(4);

    // When
    storage
        .fetch(&remote(), "alpha-dir/one.bin", 0)
        .expect("fetch");

    // Then
    assert_eq!(partial(&root), b"12345678");
    assert_eq!(
        server.requests(),
        [
            format!("GET {ONE_BIN} range=bytes=0-3"),
            format!("GET {ONE_BIN} range=bytes=4-7"),
            format!("GET {ONE_BIN} range=bytes=8-11"),
        ]
    );
}

#[test]
fn given_a_server_ignoring_range_when_resuming_then_the_partial_restarts_from_scratch() {
    // Given: stale bytes that a blind append would duplicate
    let root = TempRoot::new();
    let server = server_with(Route::IgnoresRange(b"hello world".to_vec()));
    let storage = DiskModelStorage::with_endpoint(root.path(), &server.endpoint()).chunked(4);
    seed_partial(&root, b"XXXXX");

    // When
    storage
        .fetch(&remote(), "alpha-dir/one.bin", 5)
        .expect("fetch");

    // Then
    assert_eq!(partial(&root), b"hello world");
}

fn redirect_chain_server() -> Server {
    Server::start(HashMap::from([
        (
            ONE_BIN.to_string(),
            Route::RedirectAbsolute("/hop".to_string()),
        ),
        (
            "/hop".to_string(),
            Route::RedirectRelative("/cdn".to_string()),
        ),
        (
            "/cdn".to_string(),
            Route::RangeAware(b"hello world".to_vec()),
        ),
    ]))
}

#[test]
fn given_a_redirect_chain_when_fetch_resumes_then_the_range_survives_every_hop() {
    // Given: absolute hop, then relative hop, then the CDN
    let root = TempRoot::new();
    let server = redirect_chain_server();
    let storage = DiskModelStorage::with_endpoint(root.path(), &server.endpoint()).chunked(64);
    seed_partial(&root, b"hello");

    // When
    storage
        .fetch(&remote(), "alpha-dir/one.bin", 5)
        .expect("fetch");

    // Then
    assert_eq!(partial(&root), b"hello world");
    assert_eq!(
        server.requests(),
        [
            format!("GET {ONE_BIN} range=bytes=5-68"),
            "GET /hop range=bytes=5-68".to_string(),
            "GET /cdn range=bytes=5-68".to_string(),
        ]
    );
}

#[test]
fn given_an_http_error_when_fetch_runs_then_the_report_names_the_status() {
    // Given
    let root = TempRoot::new();
    let server = server_with(Route::Status(503));
    let storage = DiskModelStorage::with_endpoint(root.path(), &server.endpoint());

    // When
    let outcome = storage.fetch(&remote(), "alpha-dir/one.bin", 0);

    // Then
    let error = outcome.expect_err("fetch must fail");
    assert!(error.message.contains("503"), "{}", error.message);
}
