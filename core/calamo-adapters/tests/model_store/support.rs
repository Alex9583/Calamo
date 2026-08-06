//! Doubles for the ModelStore seam: an in-memory `ModelStorage` whose
//! digests are opaque strings scripted per file — the logic only ever
//! compares them — plus a recording progress sink and a small catalog.

use std::cell::{Cell, RefCell};
use std::collections::{HashMap, VecDeque};

use calamo_adapters::models::catalog::{FileSpec, ModelSpec};
use calamo_adapters::models::store::{FileMeta, ModelStorage, PortError, RemoteFile};

pub const TEST_CATALOG: &[ModelSpec] = &[
    ModelSpec {
        name: "alpha",
        repo: "acme/alpha",
        revision: "rev-alpha",
        folder: "alpha-dir",
        files: &[
            FileSpec {
                path: "one.bin",
                size: 10,
                sha256: "sha-one",
            },
            FileSpec {
                path: "sub/two.bin",
                size: 20,
                sha256: "sha-two",
            },
        ],
    },
    ModelSpec {
        name: "beta",
        repo: "acme/beta",
        revision: "rev-beta",
        folder: "",
        files: &[FileSpec {
            path: "beta.gguf",
            size: 30,
            sha256: "sha-beta",
        }],
    },
];

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FakeFile {
    pub size: u64,
    pub modified_ms: i64,
    pub digest: String,
}

#[derive(Debug, Clone)]
pub struct FakePartial {
    pub len: u64,
    pub digest: String,
}

pub enum FetchOutcome {
    Completes { size: u64, digest: String },
    Fails { message: String },
}

#[derive(Default)]
pub struct InMemoryStorage {
    pub installed: RefCell<HashMap<String, FakeFile>>,
    pub partials: RefCell<HashMap<String, FakePartial>>,
    remote: RefCell<HashMap<String, VecDeque<FetchOutcome>>>,
    stamp: RefCell<Option<String>>,
    pub calls: RefCell<Vec<String>>,
    clock: Cell<i64>,
}

impl InMemoryStorage {
    pub fn new() -> Self {
        Self::default()
    }

    /// Script the remote to serve every catalog file correctly.
    pub fn serving(catalog: &[ModelSpec]) -> Self {
        let storage = Self::new();
        for model in catalog {
            for file in model.files {
                storage.serve(model, file);
            }
        }
        storage
    }

    pub fn serve(&self, model: &ModelSpec, file: &FileSpec) {
        self.serve_outcome(
            &model.local_path(file),
            FetchOutcome::Completes {
                size: file.size,
                digest: file.sha256.to_string(),
            },
        );
    }

    pub fn serve_corrupt(&self, model: &ModelSpec, file: &FileSpec) {
        self.serve_outcome(
            &model.local_path(file),
            FetchOutcome::Completes {
                size: file.size,
                digest: format!("corrupt-{}", file.sha256),
            },
        );
    }

    pub fn serve_failure(&self, model: &ModelSpec, file: &FileSpec, message: &str) {
        self.serve_outcome(
            &model.local_path(file),
            FetchOutcome::Fails {
                message: message.to_string(),
            },
        );
    }

    fn serve_outcome(&self, path: &str, outcome: FetchOutcome) {
        self.remote
            .borrow_mut()
            .entry(path.to_string())
            .or_default()
            .push_back(outcome);
    }

    /// Install a catalog file with correct bytes, as a completed run left it.
    pub fn install(&self, model: &ModelSpec, file: &FileSpec) {
        self.install_with_digest(model, file, file.sha256);
    }

    pub fn install_all(&self, catalog: &[ModelSpec]) {
        for model in catalog {
            for file in model.files {
                self.install(model, file);
            }
        }
    }

    pub fn install_with_digest(&self, model: &ModelSpec, file: &FileSpec, digest: &str) {
        self.installed.borrow_mut().insert(
            model.local_path(file),
            FakeFile {
                size: file.size,
                modified_ms: self.tick(),
                digest: digest.to_string(),
            },
        );
    }

    pub fn leave_partial(&self, model: &ModelSpec, file: &FileSpec, len: u64, digest: &str) {
        self.partials.borrow_mut().insert(
            model.local_path(file),
            FakePartial {
                len,
                digest: digest.to_string(),
            },
        );
    }

    pub fn set_stamp(&self, contents: &str) {
        *self.stamp.borrow_mut() = Some(contents.to_string());
    }

    pub fn touch(&self, model: &ModelSpec, file: &FileSpec) {
        let path = model.local_path(file);
        let mut installed = self.installed.borrow_mut();
        let entry = installed.get_mut(&path).expect("touch of absent file");
        entry.modified_ms = self.tick();
    }

    pub fn calls(&self) -> Vec<String> {
        self.calls.borrow().clone()
    }

    pub fn digest_calls(&self) -> Vec<String> {
        self.calls()
            .into_iter()
            .filter(|c| c.starts_with("hash"))
            .collect()
    }

    pub fn fetch_calls(&self) -> Vec<String> {
        self.calls()
            .into_iter()
            .filter(|c| c.starts_with("fetch"))
            .collect()
    }

    fn tick(&self) -> i64 {
        self.clock.set(self.clock.get() + 1);
        self.clock.get()
    }

    fn log(&self, call: String) {
        self.calls.borrow_mut().push(call);
    }
}

impl ModelStorage for InMemoryStorage {
    fn installed_meta(&self, path: &str) -> Result<Option<FileMeta>, PortError> {
        Ok(self.installed.borrow().get(path).map(|f| FileMeta {
            size: f.size,
            modified_ms: f.modified_ms,
        }))
    }

    fn installed_digest(&self, path: &str) -> Result<String, PortError> {
        self.log(format!("hash-installed {path}"));
        Ok(self.installed.borrow()[path].digest.clone())
    }

    fn remove_installed(&self, path: &str) -> Result<(), PortError> {
        self.log(format!("remove {path}"));
        self.installed.borrow_mut().remove(path);
        Ok(())
    }

    fn partial_len(&self, path: &str) -> Result<u64, PortError> {
        Ok(self.partials.borrow().get(path).map_or(0, |p| p.len))
    }

    fn partial_digest(&self, path: &str) -> Result<String, PortError> {
        self.log(format!("hash-partial {path}"));
        Ok(self.partials.borrow()[path].digest.clone())
    }

    fn discard_partial(&self, path: &str) -> Result<(), PortError> {
        self.log(format!("discard {path}"));
        self.partials.borrow_mut().remove(path);
        Ok(())
    }

    fn fetch(
        &self,
        remote: &RemoteFile<'_>,
        path: &str,
        resume_from: u64,
    ) -> Result<(), PortError> {
        self.log(format!(
            "fetch {}@{}/{} -> {path} @{resume_from}",
            remote.repo, remote.revision, remote.path
        ));
        let outcome = self
            .remote
            .borrow_mut()
            .get_mut(path)
            .and_then(VecDeque::pop_front)
            .unwrap_or_else(|| panic!("unscripted fetch of {path}"));
        match outcome {
            FetchOutcome::Completes { size, digest } => {
                self.partials
                    .borrow_mut()
                    .insert(path.to_string(), FakePartial { len: size, digest });
                Ok(())
            }
            FetchOutcome::Fails { message } => Err(PortError { message }),
        }
    }

    fn promote(&self, path: &str) -> Result<(), PortError> {
        self.log(format!("promote {path}"));
        let partial = self
            .partials
            .borrow_mut()
            .remove(path)
            .unwrap_or_else(|| panic!("promote of absent partial {path}"));
        self.installed.borrow_mut().insert(
            path.to_string(),
            FakeFile {
                size: partial.len,
                modified_ms: self.tick(),
                digest: partial.digest,
            },
        );
        Ok(())
    }

    fn read_stamp(&self) -> Option<String> {
        self.stamp.borrow().clone()
    }

    fn write_stamp(&self, contents: &str) -> Result<(), PortError> {
        *self.stamp.borrow_mut() = Some(contents.to_string());
        Ok(())
    }
}

#[derive(Default)]
pub struct RecordingProgress {
    pub events: RefCell<Vec<(u32, u32)>>,
}

impl RecordingProgress {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn events(&self) -> Vec<(u32, u32)> {
        self.events.borrow().clone()
    }
}

impl calamo_adapters::models::store::StoreProgress for RecordingProgress {
    fn models_ready(&self, ready: u32, total: u32) {
        self.events.borrow_mut().push((ready, total));
    }
}
