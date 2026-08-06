//! `ensure` converges the store root onto the catalog: verify what is
//! there, resume or download what is not, install nothing unverified.
//! All I/O sits behind `ModelStorage`; this module only decides.

use super::catalog::{FileSpec, ModelSpec};
use super::stamp::Stamp;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FileMeta {
    pub size: u64,
    pub modified_ms: i64,
}

pub struct RemoteFile<'a> {
    pub repo: &'a str,
    pub revision: &'a str,
    pub path: &'a str,
}

#[derive(Debug)]
pub struct PortError {
    pub message: String,
}

/// Bytes at rest and in flight under the store root. `path` is always
/// root-relative; a "partial" is the in-progress download alongside its
/// final path.
pub trait ModelStorage {
    fn installed_meta(&self, path: &str) -> Result<Option<FileMeta>, PortError>;
    fn installed_digest(&self, path: &str) -> Result<String, PortError>;
    fn remove_installed(&self, path: &str) -> Result<(), PortError>;
    fn partial_len(&self, path: &str) -> Result<u64, PortError>;
    fn partial_digest(&self, path: &str) -> Result<String, PortError>;
    fn discard_partial(&self, path: &str) -> Result<(), PortError>;
    /// Append to the partial from `resume_from` until the remote is drained.
    fn fetch(&self, remote: &RemoteFile<'_>, path: &str, resume_from: u64)
        -> Result<(), PortError>;
    /// Atomically move the verified partial into place.
    fn promote(&self, path: &str) -> Result<(), PortError>;
    fn read_stamp(&self) -> Option<String>;
    fn write_stamp(&self, contents: &str) -> Result<(), PortError>;
}

pub trait StoreProgress {
    fn models_ready(&self, ready: u32, total: u32);
}

#[derive(Debug)]
pub enum StoreError {
    Download { path: String, message: String },
    Corrupted { path: String },
    Io { path: String, message: String },
}

impl std::fmt::Display for StoreError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Download { path, message } => write!(f, "download of {path} failed: {message}"),
            Self::Corrupted { path } => {
                write!(
                    f,
                    "{path} does not match its pinned SHA-256 after redownload"
                )
            }
            Self::Io { path, message } => write!(f, "store I/O on {path} failed: {message}"),
        }
    }
}

impl std::error::Error for StoreError {}

pub fn ensure(
    catalog: &[ModelSpec],
    storage: &dyn ModelStorage,
    progress: &dyn StoreProgress,
) -> Result<(), StoreError> {
    let stamp = Stamp::parse(storage.read_stamp().as_deref());
    let mut next = Stamp::default();
    let result = converge(catalog, storage, progress, &stamp, &mut next);
    // The stamp is a verification cache: losing it costs a re-hash, never
    // data — so a failed write never masks the convergence outcome.
    let _ = storage.write_stamp(&next.render());
    result
}

type Pending<'a> = (&'a ModelSpec, Vec<(&'a FileSpec, String)>);

fn converge(
    catalog: &[ModelSpec],
    storage: &dyn ModelStorage,
    progress: &dyn StoreProgress,
    stamp: &Stamp,
    next: &mut Stamp,
) -> Result<(), StoreError> {
    let pending = classify(catalog, storage, stamp, next)?;
    if pending.is_empty() {
        return Ok(());
    }
    let total = u32::try_from(catalog.len()).unwrap_or(u32::MAX);
    let mut ready = total - u32::try_from(pending.len()).unwrap_or(u32::MAX);
    progress.models_ready(ready, total);
    for (model, files) in pending {
        for (file, path) in files {
            download(model, file, &path, storage, next)?;
        }
        ready += 1;
        progress.models_ready(ready, total);
    }
    Ok(())
}

fn classify<'a>(
    catalog: &'a [ModelSpec],
    storage: &dyn ModelStorage,
    stamp: &Stamp,
    next: &mut Stamp,
) -> Result<Vec<Pending<'a>>, StoreError> {
    let mut pending = Vec::new();
    for model in catalog {
        let mut missing = Vec::new();
        for file in model.files {
            let path = model.local_path(file);
            if !verified(file, &path, storage, stamp, next)? {
                missing.push((file, path));
            }
        }
        if !missing.is_empty() {
            pending.push((model, missing));
        }
    }
    Ok(pending)
}

fn verified(
    file: &FileSpec,
    path: &str,
    storage: &dyn ModelStorage,
    stamp: &Stamp,
    next: &mut Stamp,
) -> Result<bool, StoreError> {
    let Some(meta) = storage.installed_meta(path).map_err(io(path))? else {
        return Ok(false);
    };
    if meta.size != file.size {
        storage.remove_installed(path).map_err(io(path))?;
        return Ok(false);
    }
    if stamp.covers(path, file.sha256, &meta)
        || storage.installed_digest(path).map_err(io(path))? == file.sha256
    {
        next.record(path, file.sha256, &meta);
        return Ok(true);
    }
    storage.remove_installed(path).map_err(io(path))?;
    Ok(false)
}

fn download(
    model: &ModelSpec,
    file: &FileSpec,
    path: &str,
    storage: &dyn ModelStorage,
    next: &mut Stamp,
) -> Result<(), StoreError> {
    let remote = RemoteFile {
        repo: model.repo,
        revision: model.revision,
        path: file.path,
    };
    resume(&remote, file, path, storage)?;
    if install_if_verified(file, path, storage, next)? {
        return Ok(());
    }
    // A resumed partial may hide stale bytes: one fresh fetch before giving up.
    storage.discard_partial(path).map_err(io(path))?;
    fetch(&remote, path, 0, storage)?;
    if install_if_verified(file, path, storage, next)? {
        return Ok(());
    }
    storage.discard_partial(path).map_err(io(path))?;
    Err(StoreError::Corrupted {
        path: path.to_string(),
    })
}

fn resume(
    remote: &RemoteFile<'_>,
    file: &FileSpec,
    path: &str,
    storage: &dyn ModelStorage,
) -> Result<(), StoreError> {
    let mut already = storage.partial_len(path).map_err(io(path))?;
    if already > file.size {
        storage.discard_partial(path).map_err(io(path))?;
        already = 0;
    }
    if already < file.size {
        fetch(remote, path, already, storage)?;
    }
    Ok(())
}

fn fetch(
    remote: &RemoteFile<'_>,
    path: &str,
    from: u64,
    storage: &dyn ModelStorage,
) -> Result<(), StoreError> {
    storage
        .fetch(remote, path, from)
        .map_err(|e| StoreError::Download {
            path: path.to_string(),
            message: e.message,
        })
}

fn install_if_verified(
    file: &FileSpec,
    path: &str,
    storage: &dyn ModelStorage,
    next: &mut Stamp,
) -> Result<bool, StoreError> {
    if storage.partial_digest(path).map_err(io(path))? != file.sha256 {
        return Ok(false);
    }
    storage.promote(path).map_err(io(path))?;
    if let Some(meta) = storage.installed_meta(path).map_err(io(path))? {
        next.record(path, file.sha256, &meta);
    }
    Ok(true)
}

fn io(path: &str) -> impl Fn(PortError) -> StoreError + '_ {
    move |e| StoreError::Io {
        path: path.to_string(),
        message: e.message,
    }
}
