//! The engine thread: decodes the fixed prefix once per glossary, snapshots
//! the full llama state, restores that snapshot before every dictation — no
//! partial KV rollback — then greedy-decodes (temperature 0) the cleaned
//! text.

use std::num::NonZeroU32;
use std::path::Path;
use std::sync::mpsc::{Receiver, Sender};

use calamo_core::ports::CleanupError;
use llama_cpp_2::context::params::LlamaContextParams;
use llama_cpp_2::context::LlamaContext;
use llama_cpp_2::llama_backend::LlamaBackend;
use llama_cpp_2::llama_batch::LlamaBatch;
use llama_cpp_2::model::params::LlamaModelParams;
use llama_cpp_2::model::{AddBos, LlamaModel};
use llama_cpp_2::sampling::LlamaSampler;
use llama_cpp_2::token::LlamaToken;

use crate::cleanup::prompt;

const CONTEXT_TOKENS: u32 = 4096;
const BATCH_TOKENS: usize = 2048;

pub(super) struct Request {
    pub transcript: String,
    pub glossary: Vec<String>,
    pub reply: Sender<Result<String, CleanupError>>,
}

pub(super) fn run(gguf: &Path, ready: &Sender<Result<(), String>>, requests: &Receiver<Request>) {
    let (backend, model) = match load_model(gguf) {
        Ok(loaded) => loaded,
        Err(message) => {
            let _ = ready.send(Err(message));
            return;
        }
    };
    // The context borrows the model: both must live on this stack frame, so
    // its creation stays here.
    let context_params = LlamaContextParams::default()
        .with_n_ctx(NonZeroU32::new(CONTEXT_TOKENS))
        .with_n_batch(BATCH_TOKENS as u32);
    let context = match model.new_context(&backend, context_params) {
        Ok(context) => context,
        Err(e) => {
            let _ = ready.send(Err(format!("llama context: {e}")));
            return;
        }
    };
    let _ = ready.send(Ok(()));

    let mut engine = Engine {
        model: &model,
        context,
        prefix: None,
    };
    // Decode the glossary-less prefix now, overlapping the shell's ASR load:
    // the first dictation then only pays the snapshot restore. A failure here
    // resurfaces on the first clean.
    let _ = engine.ensure_prefix(&[]);
    while let Ok(request) = requests.recv() {
        let result = engine.clean(&request.transcript, &request.glossary);
        let _ = request.reply.send(result);
    }
}

fn load_model(gguf: &Path) -> Result<(LlamaBackend, LlamaModel), String> {
    // llama.cpp logs to stderr by default, on every dictation; route them
    // to `tracing` instead (silent unless the host installs a subscriber).
    llama_cpp_2::send_logs_to_tracing(llama_cpp_2::LogOptions::default());
    let backend = LlamaBackend::init().map_err(|e| format!("llama backend: {e}"))?;
    let params = LlamaModelParams::default().with_n_gpu_layers(99);
    let model = LlamaModel::load_from_file(&backend, gguf, &params)
        .map_err(|e| format!("model load: {e}"))?;
    Ok((backend, model))
}

struct Engine<'m> {
    model: &'m LlamaModel,
    context: LlamaContext<'m>,
    prefix: Option<Prefix>,
}

struct Prefix {
    glossary: Vec<String>,
    tokens: usize,
    state: Vec<u8>,
}

impl Engine<'_> {
    fn clean(&mut self, transcript: &str, glossary: &[String]) -> Result<String, CleanupError> {
        self.ensure_prefix(glossary)?;
        self.restore_prefix()?;
        self.generate(transcript)
    }

    /// Paid once per glossary — a dictionary edit re-decodes the prefix, a
    /// dictation only pays the snapshot restore.
    fn ensure_prefix(&mut self, glossary: &[String]) -> Result<(), CleanupError> {
        if self
            .prefix
            .as_ref()
            .is_some_and(|prefix| prefix.glossary == glossary)
        {
            return Ok(());
        }
        let terms: Vec<&str> = glossary.iter().map(String::as_str).collect();
        let tokens = self.tokenize(&prompt::prefix(&terms))?;
        self.context.clear_kv_cache();
        self.decode(&tokens, 0, false)?;
        let state = self.snapshot();
        self.prefix = Some(Prefix {
            glossary: glossary.to_vec(),
            tokens: tokens.len(),
            state,
        });
        Ok(())
    }

    fn snapshot(&mut self) -> Vec<u8> {
        let mut state = vec![0u8; self.context.get_state_size()];
        // SAFETY: the buffer holds get_state_size() bytes, the documented upper bound.
        let written = unsafe { self.context.copy_state_data(state.as_mut_ptr()) };
        state.truncate(written);
        state.shrink_to_fit();
        state
    }

    fn restore_prefix(&mut self) -> Result<(), CleanupError> {
        let prefix = self.prefix.as_ref().expect("ensured before any restore");
        // SAFETY: the slice is a state this very context serialized.
        let read = unsafe { self.context.set_state_data(&prefix.state) };
        if read == prefix.state.len() {
            Ok(())
        } else {
            Err(error(format!(
                "prefix restore read {read} of {} bytes",
                prefix.state.len()
            )))
        }
    }

    fn generate(&mut self, transcript: &str) -> Result<String, CleanupError> {
        let (position, budget) = self.decode_dictation_turn(transcript)?;
        let generated = self.greedy_until_eog(position, budget)?;
        self.cleaned_text(&generated)
    }

    /// Returns the next decode position and the generation budget.
    fn decode_dictation_turn(&mut self, transcript: &str) -> Result<(usize, usize), CleanupError> {
        let prefix_tokens = self.prefix.as_ref().expect("ensured").tokens;
        let turn = self.tokenize(&prompt::dictation_turn(transcript))?;
        // A cleanup is at most its dictation plus punctuation: anything past
        // this budget is a runaway generation, degrade instead.
        let budget = 2 * turn.len() + 64;
        if prefix_tokens + turn.len() + budget >= CONTEXT_TOKENS as usize {
            return Err(error(format!(
                "dictation overflows the {CONTEXT_TOKENS}-token context"
            )));
        }
        self.decode(&turn, prefix_tokens, true)?;
        Ok((prefix_tokens + turn.len(), budget))
    }

    fn greedy_until_eog(
        &mut self,
        mut position: usize,
        budget: usize,
    ) -> Result<Vec<LlamaToken>, CleanupError> {
        let mut sampler = LlamaSampler::greedy();
        let mut generated = Vec::new();
        loop {
            let token = sampler.sample(&self.context, -1);
            if self.model.is_eog_token(token) {
                return Ok(generated);
            }
            generated.push(token);
            if generated.len() > budget {
                return Err(error("generation overran its budget"));
            }
            self.decode(&[token], position, true)?;
            position += 1;
        }
    }

    fn cleaned_text(&self, generated: &[LlamaToken]) -> Result<String, CleanupError> {
        let text = self.detokenize(generated)?;
        let text = text.trim();
        if text.is_empty() {
            return Err(error("empty cleanup output"));
        }
        Ok(text.to_string())
    }

    fn decode(
        &mut self,
        tokens: &[LlamaToken],
        first_position: usize,
        want_logits: bool,
    ) -> Result<(), CleanupError> {
        for chunk_start in (0..tokens.len()).step_by(BATCH_TOKENS) {
            let chunk = &tokens[chunk_start..tokens.len().min(chunk_start + BATCH_TOKENS)];
            let mut batch = LlamaBatch::new(chunk.len(), 1);
            for (offset, &token) in chunk.iter().enumerate() {
                let index = chunk_start + offset;
                let logits = want_logits && index == tokens.len() - 1;
                batch
                    .add(token, (first_position + index) as i32, &[0], logits)
                    .map_err(|e| error(format!("batch: {e}")))?;
            }
            self.context
                .decode(&mut batch)
                .map_err(|e| error(format!("decode: {e}")))?;
        }
        Ok(())
    }

    fn tokenize(&self, text: &str) -> Result<Vec<LlamaToken>, CleanupError> {
        self.model
            .str_to_token(text, AddBos::Never)
            .map_err(|e| error(format!("tokenize: {e}")))
    }

    fn detokenize(&self, tokens: &[LlamaToken]) -> Result<String, CleanupError> {
        let mut bytes = Vec::with_capacity(tokens.len() * 4);
        for &token in tokens {
            bytes.extend_from_slice(&self.piece_bytes(token)?);
        }
        String::from_utf8(bytes).map_err(|e| error(format!("detokenize: {e}")))
    }

    fn piece_bytes(&self, token: LlamaToken) -> Result<Vec<u8>, CleanupError> {
        use llama_cpp_2::TokenToStringError::InsufficientBufferSpace;
        let mut capacity = 32;
        loop {
            match self
                .model
                .token_to_piece_bytes(token, capacity, false, None)
            {
                Err(InsufficientBufferSpace(_)) => capacity *= 4,
                piece => return piece.map_err(|e| error(format!("detokenize: {e}"))),
            }
        }
    }
}

fn error(message: impl Into<String>) -> CleanupError {
    CleanupError {
        message: message.into(),
    }
}
