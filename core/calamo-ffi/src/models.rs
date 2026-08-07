//! The exported ModelStore: the pinned catalog installed at its definitive
//! root, driven from the shell's loader thread.

use std::path::Path;
use std::sync::{Arc, Mutex, PoisonError};

use calamo_adapters::models::catalog;
use calamo_adapters::models::disk::DiskModelStorage;
use calamo_adapters::models::store;

#[derive(uniffi::Object)]
pub struct ModelStore {
    root: String,
    // Two concurrent ensures would race on the same partial files.
    busy: Mutex<()>,
}

/// Deterministic layout under the store root — valid before any byte lands.
#[derive(Debug, Clone, PartialEq, uniffi::Record)]
pub struct ModelPaths {
    pub asr_tdt_dir: String,
    pub asr_ctc_dir: String,
    pub cleanup_gguf: String,
}

/// One pinned model as the onboarding wizard announces it.
#[derive(Debug, Clone, PartialEq, uniffi::Record)]
pub struct CatalogModel {
    pub name: String,
    pub bytes: u64,
}

#[uniffi::export]
pub fn model_catalog() -> Vec<CatalogModel> {
    catalog::CATALOG
        .iter()
        .map(|model| CatalogModel {
            name: model.display_name.to_string(),
            bytes: model.files.iter().map(|f| f.size).sum(),
        })
        .collect()
}

#[uniffi::export(with_foreign)]
pub trait ModelStoreObserver: Send + Sync {
    /// Fires only when downloads happen: opening count, then one per model.
    fn models_ready(&self, ready: u32, total: u32);
}

#[derive(Debug, Clone, PartialEq, uniffi::Error)]
pub enum ModelStoreError {
    Download { path: String, message: String },
    Corrupted { path: String },
    Io { path: String, message: String },
}

impl std::fmt::Display for ModelStoreError {
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

impl std::error::Error for ModelStoreError {}

impl From<store::StoreError> for ModelStoreError {
    fn from(e: store::StoreError) -> Self {
        match e {
            store::StoreError::Download { path, message } => Self::Download { path, message },
            store::StoreError::Corrupted { path } => Self::Corrupted { path },
            store::StoreError::Io { path, message } => Self::Io { path, message },
        }
    }
}

#[uniffi::export]
impl ModelStore {
    #[uniffi::constructor]
    pub fn new(root: String) -> Arc<Self> {
        Arc::new(Self {
            root,
            busy: Mutex::new(()),
        })
    }

    pub fn paths(&self) -> ModelPaths {
        let join = |leaf: &str| {
            Path::new(&self.root)
                .join(leaf)
                .to_string_lossy()
                .into_owned()
        };
        ModelPaths {
            asr_tdt_dir: join(catalog::tdt().folder),
            asr_ctc_dir: join(catalog::ctc().folder),
            cleanup_gguf: join(catalog::GGUF_FILE_NAME),
        }
    }

    /// Blocks while downloading and verifying — call it off the main thread.
    pub fn ensure(&self, observer: Arc<dyn ModelStoreObserver>) -> Result<(), ModelStoreError> {
        let _serial = self.busy.lock().unwrap_or_else(PoisonError::into_inner);
        let storage = DiskModelStorage::at(self.root.as_str());
        store::ensure(catalog::CATALOG, &storage, &ProgressBridge(observer)).map_err(Into::into)
    }
}

struct ProgressBridge(Arc<dyn ModelStoreObserver>);

impl store::StoreProgress for ProgressBridge {
    fn models_ready(&self, ready: u32, total: u32) {
        self.0.models_ready(ready, total);
    }
}
