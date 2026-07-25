//! The `CleanupPort` adapter: Qwen3.5-2B via llama.cpp behind the reference
//! cleanup prompt. `prompt` is pure and always compiled; the engine itself
//! sits behind the `llama-cleanup` feature and only supports macOS/Metal.

pub mod prompt;

#[cfg(all(feature = "llama-cleanup", target_os = "macos"))]
mod llama;
#[cfg(all(feature = "llama-cleanup", target_os = "macos"))]
pub use llama::{CleanupSetupError, LlamaCleanup, PINNED_GGUF_SHA256};
