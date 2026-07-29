//! `CleanupPort` over llama-cpp-2 on Metal. A dedicated engine thread owns
//! backend, model and context (`LlamaContext` borrows its model, so both live
//! on that thread's stack); the port stays synchronous over a channel bridge.
//! llama.cpp's backend is process-global: one live instance at a time.

mod worker;

use std::fmt;
use std::path::{Path, PathBuf};
use std::sync::mpsc;
use std::thread::JoinHandle;

use calamo_core::dictation::RawTranscript;
use calamo_core::ports::{CleanupError, CleanupPort};

/// `unsloth/Qwen3.5-2B-GGUF` `Qwen3.5-2B-Q4_K_M.gguf`, the model locked by
/// the cleanup prototype.
pub const PINNED_GGUF_SHA256: &str =
    "aaf42c8b7c3cab2bf3d69c355048d4a0ee9973d48f16c731c0520ee914699223";

pub struct LlamaCleanup {
    requests: Option<mpsc::Sender<worker::Request>>,
    engine: Option<JoinHandle<()>>,
}

#[derive(Debug)]
pub enum CleanupSetupError {
    ModelFile { path: PathBuf, message: String },
    ChecksumMismatch { path: PathBuf, actual: String },
    Engine { message: String },
}

impl fmt::Display for CleanupSetupError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::ModelFile { path, message } => {
                write!(f, "unreadable model file {}: {message}", path.display())
            }
            Self::ChecksumMismatch { path, actual } => write!(
                f,
                "model file {} is not the pinned GGUF: SHA-256 {actual}, expected {PINNED_GGUF_SHA256}",
                path.display()
            ),
            Self::Engine { message } => write!(f, "cleanup engine failed to start: {message}"),
        }
    }
}

impl std::error::Error for CleanupSetupError {}

impl LlamaCleanup {
    /// Verifies the GGUF against the pin, then loads it on the engine thread
    /// (whole model offloaded to Metal). Blocks until the model is ready.
    pub fn load(gguf: &Path) -> Result<Self, CleanupSetupError> {
        verify_pinned_checksum(gguf)?;
        let (ready_tx, ready_rx) = mpsc::channel();
        let (request_tx, request_rx) = mpsc::channel();
        let path = gguf.to_path_buf();
        let engine = std::thread::Builder::new()
            .name("calamo-cleanup".into())
            .spawn(move || worker::run(&path, &ready_tx, &request_rx))
            .map_err(|e| CleanupSetupError::Engine {
                message: e.to_string(),
            })?;
        let startup = ready_rx
            .recv()
            .unwrap_or_else(|_| Err("engine thread died".into()));
        match startup {
            Ok(()) => Ok(Self {
                requests: Some(request_tx),
                engine: Some(engine),
            }),
            Err(message) => {
                drop(request_tx);
                let _ = engine.join();
                Err(CleanupSetupError::Engine { message })
            }
        }
    }
}

impl CleanupPort for LlamaCleanup {
    fn clean(&self, transcript: &RawTranscript, glossary: &[&str]) -> Result<String, CleanupError> {
        let (reply_tx, reply_rx) = mpsc::channel();
        let request = worker::Request::Clean {
            transcript: transcript.text().to_string(),
            glossary: owned(glossary),
            reply: reply_tx,
        };
        let requests = self.requests.as_ref().expect("present until drop");
        requests.send(request).map_err(|_| engine_gone())?;
        reply_rx.recv().map_err(|_| engine_gone())?
    }

    /// Queued behind any in-flight clean, decoded on the engine thread: the
    /// caller never waits, dictations in progress keep their prefix.
    fn warm_glossary(&self, glossary: &[&str]) {
        let request = worker::Request::Warm {
            glossary: owned(glossary),
        };
        let requests = self.requests.as_ref().expect("present until drop");
        let _ = requests.send(request);
    }
}

fn owned(glossary: &[&str]) -> Vec<String> {
    glossary.iter().map(|term| term.to_string()).collect()
}

fn engine_gone() -> CleanupError {
    CleanupError {
        message: "cleanup engine thread is gone".into(),
    }
}

impl Drop for LlamaCleanup {
    /// Closing the request channel ends the engine thread; joining it frees
    /// the Metal context before the process moves on.
    fn drop(&mut self) {
        self.requests.take();
        if let Some(engine) = self.engine.take() {
            let _ = engine.join();
        }
    }
}

fn verify_pinned_checksum(path: &Path) -> Result<(), CleanupSetupError> {
    use sha2::{Digest, Sha256};
    let model_file = |e: std::io::Error| CleanupSetupError::ModelFile {
        path: path.to_path_buf(),
        message: e.to_string(),
    };
    let mut file = std::fs::File::open(path).map_err(model_file)?;
    let mut hasher = Sha256::new();
    std::io::copy(&mut file, &mut hasher).map_err(model_file)?;
    let actual = format!("{:x}", hasher.finalize());
    if actual == PINNED_GGUF_SHA256 {
        Ok(())
    } else {
        Err(CleanupSetupError::ChecksumMismatch {
            path: path.to_path_buf(),
            actual,
        })
    }
}
