//! Promote's same-directory rename is the atomic write. Redirects are
//! walked by hand so Range survives the hop to the CDN; the store's digest
//! check arbitrates whatever the server returns.

use std::fs::{self, Metadata, OpenOptions};
use std::io;
use std::path::{Path, PathBuf};
use std::time::{Duration, SystemTime};

use sha2::{Digest, Sha256};
use ureq::Agent;

use super::store::{FileMeta, ModelStorage, PortError, RemoteFile};

const STAMP_FILE: &str = ".calamo-store-stamp";
const MAX_HOPS: usize = 5;
// 8 MiB under a 120 s body timeout: stalls die in minutes, links down to
// ~0.5 Mbps still make progress.
const CHUNK: u64 = 8 * 1024 * 1024;

type Response = ureq::http::Response<ureq::Body>;

enum ChunkOutcome {
    More { from: u64 },
    Done,
}

pub struct DiskModelStorage {
    root: PathBuf,
    endpoint: String,
    chunk: u64,
    agent: Agent,
}

impl DiskModelStorage {
    pub fn at(root: impl Into<PathBuf>) -> Self {
        Self::with_endpoint(root, "https://huggingface.co")
    }

    /// The endpoint override exists for the loopback tests.
    pub fn with_endpoint(root: impl Into<PathBuf>, endpoint: &str) -> Self {
        let config = Agent::config_builder()
            .max_redirects(0)
            .http_status_as_error(false)
            .timeout_connect(Some(Duration::from_secs(15)))
            .timeout_recv_response(Some(Duration::from_secs(30)))
            .timeout_recv_body(Some(Duration::from_secs(120)))
            .build();
        Self {
            root: root.into(),
            endpoint: endpoint.trim_end_matches('/').to_string(),
            chunk: CHUNK,
            agent: Agent::new_with_config(config),
        }
    }

    /// Test hook: shrink the chunk so the loopback suite walks the loop.
    pub fn chunked(mut self, bytes: u64) -> Self {
        self.chunk = bytes;
        self
    }

    fn installed_path(&self, path: &str) -> PathBuf {
        self.root.join(path)
    }

    fn partial_path(&self, path: &str) -> PathBuf {
        self.root.join(format!("{path}.partial"))
    }

    fn request(&self, url: &str, from: u64) -> Result<Response, PortError> {
        self.agent
            .get(url)
            .header("Range", format!("bytes={from}-{}", from + self.chunk - 1))
            .call()
            .map_err(|e| PortError {
                message: e.to_string(),
            })
    }

    /// Redirects re-walk from the original URL: CDN targets are signed and
    /// may not outlive a chunk.
    fn fetch_chunk(&self, url: &str, path: &str, from: u64) -> Result<ChunkOutcome, PortError> {
        let mut url = url.to_string();
        for _ in 0..MAX_HOPS {
            let mut response = self.request(&url, from)?;
            match response.status().as_u16() {
                301 | 302 | 303 | 307 | 308 => url = redirect_target(&response, &url)?,
                206 => return self.append_chunk(&mut response, path, from),
                // Range ignored: one unbounded pass from byte zero.
                200 => {
                    self.write_partial(&mut response, path, false)?;
                    return Ok(ChunkOutcome::Done);
                }
                // Past the end: the previous chunk landed exactly on it.
                416 => return Ok(ChunkOutcome::Done),
                status => {
                    return Err(PortError {
                        message: format!("HTTP {status} fetching {url}"),
                    })
                }
            }
        }
        Err(PortError {
            message: format!("too many redirects fetching {url}"),
        })
    }

    fn append_chunk(
        &self,
        response: &mut Response,
        path: &str,
        from: u64,
    ) -> Result<ChunkOutcome, PortError> {
        let written = self.write_partial(response, path, true)?;
        Ok(if written < self.chunk {
            ChunkOutcome::Done
        } else {
            ChunkOutcome::More {
                from: from + written,
            }
        })
    }

    fn write_partial(
        &self,
        response: &mut Response,
        path: &str,
        append: bool,
    ) -> Result<u64, PortError> {
        let partial = self.partial_path(path);
        if let Some(parent) = partial.parent() {
            fs::create_dir_all(parent).map_err(io_error)?;
        }
        let mut options = OpenOptions::new();
        if append {
            options.append(true);
        } else {
            options.write(true).truncate(true);
        }
        let mut file = options.create(true).open(&partial).map_err(io_error)?;
        io::copy(&mut response.body_mut().as_reader(), &mut file).map_err(io_error)
    }
}

impl ModelStorage for DiskModelStorage {
    fn installed_meta(&self, path: &str) -> Result<Option<FileMeta>, PortError> {
        match fs::metadata(self.installed_path(path)) {
            Ok(meta) => Ok(Some(FileMeta {
                size: meta.len(),
                modified_ms: modified_ms(&meta),
            })),
            Err(e) if e.kind() == io::ErrorKind::NotFound => Ok(None),
            Err(e) => Err(io_error(e)),
        }
    }

    fn installed_digest(&self, path: &str) -> Result<String, PortError> {
        sha256_of(&self.installed_path(path))
    }

    fn remove_installed(&self, path: &str) -> Result<(), PortError> {
        remove_if_present(&self.installed_path(path))
    }

    fn partial_len(&self, path: &str) -> Result<u64, PortError> {
        match fs::metadata(self.partial_path(path)) {
            Ok(meta) => Ok(meta.len()),
            Err(e) if e.kind() == io::ErrorKind::NotFound => Ok(0),
            Err(e) => Err(io_error(e)),
        }
    }

    fn partial_digest(&self, path: &str) -> Result<String, PortError> {
        sha256_of(&self.partial_path(path))
    }

    fn discard_partial(&self, path: &str) -> Result<(), PortError> {
        remove_if_present(&self.partial_path(path))
    }

    fn fetch(
        &self,
        remote: &RemoteFile<'_>,
        path: &str,
        resume_from: u64,
    ) -> Result<(), PortError> {
        let url = format!(
            "{}/{}/resolve/{}/{}",
            self.endpoint, remote.repo, remote.revision, remote.path
        );
        let mut from = resume_from;
        loop {
            match self.fetch_chunk(&url, path, from)? {
                ChunkOutcome::More { from: next } if next > from => from = next,
                _ => return Ok(()),
            }
        }
    }

    fn promote(&self, path: &str) -> Result<(), PortError> {
        fs::rename(self.partial_path(path), self.installed_path(path)).map_err(io_error)
    }

    fn read_stamp(&self) -> Option<String> {
        fs::read_to_string(self.root.join(STAMP_FILE)).ok()
    }

    fn write_stamp(&self, contents: &str) -> Result<(), PortError> {
        fs::create_dir_all(&self.root).map_err(io_error)?;
        fs::write(self.root.join(STAMP_FILE), contents).map_err(io_error)
    }
}

fn redirect_target(response: &Response, from: &str) -> Result<String, PortError> {
    let location = response
        .headers()
        .get("location")
        .and_then(|v| v.to_str().ok())
        .ok_or_else(|| PortError {
            message: format!("redirect without a location from {from}"),
        })?;
    if location.starts_with("http://") || location.starts_with("https://") {
        return Ok(location.to_string());
    }
    match (location.strip_prefix('/'), origin_of(from)) {
        (Some(rest), Some(origin)) => Ok(format!("{origin}/{rest}")),
        _ => Err(PortError {
            message: format!("unsupported redirect target {location}"),
        }),
    }
}

fn origin_of(url: &str) -> Option<&str> {
    let authority = url.find("://")? + 3;
    match url[authority..].find('/') {
        Some(slash) => Some(&url[..authority + slash]),
        None => Some(url),
    }
}

fn sha256_of(path: &Path) -> Result<String, PortError> {
    let mut file = fs::File::open(path).map_err(io_error)?;
    let mut hasher = Sha256::new();
    io::copy(&mut file, &mut hasher).map_err(io_error)?;
    Ok(format!("{:x}", hasher.finalize()))
}

fn remove_if_present(path: &Path) -> Result<(), PortError> {
    match fs::remove_file(path) {
        Ok(()) => Ok(()),
        Err(e) if e.kind() == io::ErrorKind::NotFound => Ok(()),
        Err(e) => Err(io_error(e)),
    }
}

fn modified_ms(meta: &Metadata) -> i64 {
    let Ok(modified) = meta.modified() else {
        return 0;
    };
    match modified.duration_since(SystemTime::UNIX_EPOCH) {
        Ok(after) => i64::try_from(after.as_millis()).unwrap_or(i64::MAX),
        Err(before) => -i64::try_from(before.duration().as_millis()).unwrap_or(i64::MAX),
    }
}

fn io_error(e: io::Error) -> PortError {
    PortError {
        message: e.to_string(),
    }
}
