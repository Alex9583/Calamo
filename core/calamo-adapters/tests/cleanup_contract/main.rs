//! CleanupPort contract on the real Qwen3.5-2B adapter, driven by the data
//! vectors of fixtures/cleanup-contract.json plus the private corpus
//! manifest. Local-only: auto-skips when the pinned GGUF or the corpus is
//! absent — the cleanup_vectors_guard test keeps the data honest in CI.
#![cfg(target_os = "macos")]

// dead_code: the shared module is recompiled per test target; this one runs
// the vectors and leaves shape validation to cleanup_vectors_guard.
#[path = "../contract_data/mod.rs"]
#[allow(dead_code)]
mod contract_data;
#[path = "../text_metrics/mod.rs"]
#[allow(dead_code)]
mod text_metrics;

use std::collections::BTreeMap;
use std::path::PathBuf;
use std::time::Instant;

use calamo_adapters::cleanup::LlamaCleanup;
use calamo_core::dictation::{Language, RawTranscript};
use calamo_core::ports::CleanupPort;
use contract_data::{Contract, CorpusVector, Fixture, Manifest, SyntheticVector, VectorLanguage};

struct Harness {
    adapter: LlamaCleanup,
    contract: Contract,
    manifest: Option<Manifest>,
    glossary: Vec<String>,
}

/// One harness per process, owned by the single test so the adapter is
/// dropped before exit — a leaked Metal context trips a ggml atexit assert.
fn harness() -> Option<Harness> {
    let contract = contract_data::load_contract();
    let gguf = gguf_path();
    if !gguf.is_file() {
        eprintln!(
            "SKIP cleanup contract: pinned GGUF absent at {} \
             (override with CALAMO_CLEANUP_GGUF)",
            gguf.display()
        );
        return None;
    }
    let manifest = contract_data::load_manifest(&contract);
    let glossary = contract.glossary.terms();
    let adapter = LlamaCleanup::load(&gguf).expect("loading the pinned model");
    Some(Harness {
        adapter,
        contract,
        manifest,
        glossary,
    })
}

fn gguf_path() -> PathBuf {
    std::env::var_os("CALAMO_CLEANUP_GGUF")
        .map(PathBuf::from)
        .unwrap_or_else(|| contract_data::fixtures_dir().join("models/Qwen3.5-2B-Q4_K_M.gguf"))
}

/// The mixed takes are French-dominant; the port maps them to French.
fn core_language(language: VectorLanguage) -> Language {
    match language {
        VectorLanguage::En => Language::English,
        VectorLanguage::Fr | VectorLanguage::Mixed => Language::French,
    }
}

impl Harness {
    /// Every vector runs twice: temperature 0 over a restored prefix snapshot
    /// promises byte-identical outputs.
    fn clean_twice(
        &self,
        id: &str,
        verbatim: &str,
        language: VectorLanguage,
    ) -> Result<String, String> {
        let transcript = RawTranscript::new(verbatim, core_language(language));
        let glossary: Vec<&str> = self.glossary.iter().map(String::as_str).collect();
        let run = || {
            let started = Instant::now();
            let cleaned = self.adapter.clean(&transcript, &glossary);
            (cleaned, started.elapsed().as_millis())
        };
        let (first, first_ms) = run();
        let (again, again_ms) = run();
        eprintln!("  {id}: {first_ms} ms then {again_ms} ms");
        let first = first.map_err(|e| format!("{id}: cleanup failed: {}", e.message))?;
        let again = again.map_err(|e| format!("{id}: cleanup failed: {}", e.message))?;
        if first != again {
            return Err(format!(
                "{id}: non-deterministic output:\n  run 1: {first}\n  run 2: {again}"
            ));
        }
        Ok(first)
    }

    fn run_all_vectors(&self) -> (BTreeMap<String, String>, Vec<String>) {
        let mut outputs = BTreeMap::new();
        let mut failures = Vec::new();
        match &self.manifest {
            None => eprintln!("SKIP corpus vectors: private corpus manifest absent"),
            Some(manifest) => {
                for vector in &self.contract.corpus {
                    let fixture = manifest
                        .fixture(&vector.id)
                        .expect("guard-checked coverage");
                    match self.clean_twice(&vector.id, &fixture.verbatim, fixture.lang) {
                        Err(failure) => failures.push(failure),
                        Ok(output) => {
                            failures.extend(self.check_corpus(vector, fixture, &output));
                            outputs.insert(vector.id.clone(), output);
                        }
                    }
                }
            }
        }
        for vector in &self.contract.synthetic {
            match self.clean_twice(&vector.id, &vector.verbatim, vector.language) {
                Err(failure) => failures.push(failure),
                Ok(output) => {
                    failures.extend(self.check_synthetic(vector, &output));
                    outputs.insert(vector.id.clone(), output);
                }
            }
        }
        (outputs, failures)
    }

    fn check_corpus(&self, vector: &CorpusVector, fixture: &Fixture, output: &str) -> Vec<String> {
        let mut failures = self.breaches(&vector.id, &fixture.verbatim, output);
        if vector.identical {
            failures.extend(differs(&vector.id, &fixture.clean, output));
        }
        if let Some(bound) = vector.max_word_error_rate {
            let wer = text_metrics::word_error_rate(output, &fixture.clean);
            if wer > bound {
                failures.push(format!(
                    "{}: WER {wer:.3} above the {bound} bound:\n  expected: {}\n  got:      {}",
                    vector.id, fixture.clean, output
                ));
            }
        }
        for needle in &vector.forbidden {
            failures.extend(unexpected(&vector.id, needle, output));
        }
        failures
    }

    fn check_synthetic(&self, vector: &SyntheticVector, output: &str) -> Vec<String> {
        let mut failures = self.breaches(&vector.id, &vector.verbatim, output);
        if let Some(expected) = &vector.expected {
            failures.extend(differs(&vector.id, expected, output));
        }
        for needle in &vector.must_contain {
            if !output.contains(needle) {
                failures.push(format!("{}: missing « {needle} » in: {output}", vector.id));
            }
        }
        for needle in &vector.must_not_contain {
            failures.extend(unexpected(&vector.id, needle, output));
        }
        failures
    }

    fn breaches(&self, id: &str, verbatim: &str, output: &str) -> Vec<String> {
        text_metrics::invariant_breaches(verbatim, output, &self.glossary)
            .into_iter()
            .map(|breach| format!("{id}: {breach}"))
            .collect()
    }
}

fn differs(id: &str, expected: &str, output: &str) -> Option<String> {
    (text_metrics::norm_typo(output) != text_metrics::norm_typo(expected))
        .then(|| format!("{id}: output differs:\n  expected: {expected}\n  got:      {output}"))
}

fn unexpected(id: &str, needle: &str, output: &str) -> Option<String> {
    output
        .contains(needle)
        .then(|| format!("{id}: unexpected « {needle} » in: {output}"))
}

fn snapshot_path() -> PathBuf {
    contract_data::fixtures_dir().join("../core/target/cleanup-contract-outputs.json")
}

/// The inter-run half of the determinism promise: byte-equality against the
/// previous harness run's outputs. After an intentional prompt or vector
/// change, delete the snapshot and run twice.
fn check_previous_run(outputs: &BTreeMap<String, String>) -> Vec<String> {
    let path = snapshot_path();
    let mut failures = Vec::new();
    if let Ok(text) = std::fs::read_to_string(&path) {
        let previous: BTreeMap<String, String> = serde_json::from_str(&text).unwrap_or_default();
        for (id, output) in outputs {
            if previous.get(id).is_some_and(|prev| prev != output) {
                failures.push(format!(
                    "{id}: output drifted since the previous harness run \
                     (delete {} after an intentional change):\n  before: {}\n  now:    {output}",
                    path.display(),
                    previous[id]
                ));
            }
        }
    }
    failures
}

#[test]
fn given_the_contract_vectors_when_cleaned_on_the_real_adapter_then_expectations_and_invariants_hold(
) {
    // Given: the real adapter; corpus vectors additionally need the private
    // manifest, synthetic ones are committed inline
    let Some(harness) = harness() else { return };

    // When: every vector cleaned twice on the real adapter
    let (outputs, mut failures) = harness.run_all_vectors();

    // Then: expectations, invariants, and byte-stability across harness runs;
    // only a green AND corpus-complete run becomes the next reference — a
    // manifest-less run must not clobber the full baseline
    failures.extend(check_previous_run(&outputs));
    if failures.is_empty() && harness.manifest.is_some() {
        let _ = std::fs::write(
            snapshot_path(),
            serde_json::to_string_pretty(&outputs).unwrap(),
        );
    }
    assert!(failures.is_empty(), "\n{}", failures.join("\n"));
}
