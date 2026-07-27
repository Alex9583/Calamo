//! Cleanup golden suite: the manifest's verbatim takes through the real
//! Qwen3.5-2B adapter then SpellingEnforcement, against the clean references
//! — the LLM stage isolated from ASR. On-demand only (CALAMO_GOLDEN=1), on
//! the calibrated reference machine, never in CI.
#![cfg(target_os = "macos")]

mod baseline;
#[path = "../contract_data/mod.rs"]
#[allow(dead_code)]
mod contract_data;
#[path = "../golden_data/mod.rs"]
#[allow(dead_code)]
mod golden_data;
#[path = "../text_metrics/mod.rs"]
#[allow(dead_code)]
mod text_metrics;

use std::collections::BTreeMap;
use std::path::PathBuf;

use calamo_adapters::cleanup::{LlamaCleanup, PINNED_GGUF_SHA256};
use calamo_core::dictation::{Language, RawTranscript};
use calamo_core::dictionary::{Dictionary, DictionaryEntry};
use calamo_core::ports::CleanupPort;
use calamo_core::spelling_enforcement;
use contract_data::{Fixture, VectorLanguage};
use golden_data::GoldenVectors;

struct Suite {
    adapter: LlamaCleanup,
    vectors: GoldenVectors,
    dictionary: Dictionary,
    glossary: Vec<String>,
}

struct TakeResult {
    id: String,
    output: String,
    similarity: f64,
    failures: Vec<String>,
}

/// `None` only when golden was not requested; a requested run without the
/// corpus or the pinned model fails loudly instead of skipping.
fn suite_and_takes() -> Option<(Suite, Vec<Fixture>)> {
    if std::env::var_os("CALAMO_GOLDEN").is_none() {
        eprintln!("SKIP cleanup golden: on-demand only — scripts/golden.sh cleanup");
        return None;
    }
    let vectors = golden_data::load(&contract_data::fixtures_dir());
    let contract = contract_data::load_contract();
    let manifest = contract_data::load_manifest(&contract)
        .expect("golden requested but the private corpus manifest is absent");
    let gguf = gguf_path();
    assert!(
        gguf.is_file(),
        "golden requested but the pinned GGUF is absent at {}",
        gguf.display()
    );
    let glossary = contract.glossary.terms();
    let dictionary = Dictionary::new(glossary.iter().map(DictionaryEntry::new).collect())
        .expect("contract glossary terms are unique");
    let takes = contract
        .corpus
        .iter()
        .map(|vector| {
            manifest
                .fixture(&vector.id)
                .expect("guard-checked coverage")
                .clone()
        })
        .collect();
    let adapter = LlamaCleanup::load(&gguf).expect("loading the pinned model");
    Some((
        Suite {
            adapter,
            vectors,
            dictionary,
            glossary,
        },
        takes,
    ))
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

impl Suite {
    fn run_take(&self, fixture: &Fixture) -> TakeResult {
        match self.cleaned_and_spelled(fixture) {
            Err(failure) => TakeResult {
                id: fixture.id.clone(),
                output: String::new(),
                similarity: 0.0,
                failures: vec![failure],
            },
            Ok(output) => TakeResult {
                id: fixture.id.clone(),
                similarity: text_metrics::levenshtein_similarity04(&output, &fixture.clean),
                failures: self.hard_breaches(fixture, &output),
                output,
            },
        }
    }

    fn cleaned_and_spelled(&self, fixture: &Fixture) -> Result<String, String> {
        let transcript = RawTranscript::new(&fixture.verbatim, core_language(fixture.lang));
        let glossary: Vec<&str> = self.glossary.iter().map(String::as_str).collect();
        let cleaned = self
            .adapter
            .clean(&transcript, &glossary)
            .map_err(|e| format!("{}: cleanup failed: {}", fixture.id, e.message))?;
        Ok(spelling_enforcement::enforce(&cleaned, &self.dictionary))
    }

    /// The ticket's hard assertions: no never-dictated glossary term, and
    /// exact spellings wherever the clean reference carries one.
    fn hard_breaches(&self, fixture: &Fixture, output: &str) -> Vec<String> {
        let mut breaches: Vec<String> =
            text_metrics::never_dictated_breaches(&fixture.verbatim, output, &self.glossary)
                .into_iter()
                .map(|breach| format!("{}: {breach} in: {output}", fixture.id))
                .collect();
        for term in &self.glossary {
            if text_metrics::term_exact(term, &fixture.clean)
                && text_metrics::term_present(term, output)
                && !text_metrics::term_exact(term, output)
            {
                breaches.push(format!(
                    "{}: spelling of « {term} » not exact in: {output}",
                    fixture.id
                ));
            }
        }
        breaches
    }

    fn environment(&self) -> baseline::Environment {
        let lock_file = contract_data::fixtures_dir().join("../core/Cargo.lock");
        baseline::current_environment(BTreeMap::from([
            ("ggufSha256".into(), PINNED_GGUF_SHA256.into()),
            (
                "llamaCpp2".into(),
                baseline::locked_crate_version(&lock_file, "llama-cpp-2"),
            ),
        ]))
    }
}

fn report(result: &TakeResult, min_similarity: f64) {
    let verdict = if result.similarity < min_similarity {
        format!("  BELOW {min_similarity}")
    } else {
        String::new()
    };
    eprintln!(
        "[cleanup-golden] {}  sim {:.3}{}",
        result.id, result.similarity, verdict
    );
    for failure in &result.failures {
        eprintln!("[cleanup-golden]   HARD {failure}");
    }
}

fn similarity_breaches(results: &[TakeResult], vectors: &GoldenVectors) -> Vec<String> {
    let minimum = vectors.min_similarity_vs_clean;
    let budget = vectors.max_takes_below_similarity;
    let below: Vec<&str> = results
        .iter()
        .filter(|r| r.similarity < minimum)
        .map(|r| r.id.as_str())
        .collect();
    eprintln!(
        "[cleanup-golden] takes below {minimum}: {}/{} (budget {budget})",
        below.len(),
        results.len()
    );
    if below.len() <= budget {
        return Vec::new();
    }
    vec![format!(
        "{} takes below similarity {minimum} (budget {budget}): {}",
        below.len(),
        below.join(", ")
    )]
}

fn baseline_breaches(suite: &Suite, results: &[TakeResult]) -> Vec<String> {
    let outputs: BTreeMap<String, String> = results
        .iter()
        .map(|r| (r.id.clone(), r.output.clone()))
        .collect();
    let path = contract_data::fixtures_dir().join("audio/local/golden/cleanup-baseline.json");
    baseline::check_or_bootstrap(&path, &suite.environment(), &outputs)
}

#[test]
fn given_the_corpus_when_cleaned_and_spelled_on_the_real_adapter_then_the_golden_holds() {
    // Given: the real adapter, the private corpus, the contract glossary
    let Some((suite, takes)) = suite_and_takes() else {
        return;
    };

    // When: every verbatim through cleanup then SpellingEnforcement
    let results: Vec<TakeResult> = takes.iter().map(|f| suite.run_take(f)).collect();

    // Then: per-take report, hard assertions, literal statistical thresholds,
    // and byte-stability against the baseline
    let mut failures = Vec::new();
    for result in &results {
        report(result, suite.vectors.min_similarity_vs_clean);
        failures.extend(result.failures.iter().cloned());
    }
    failures.extend(similarity_breaches(&results, &suite.vectors));
    failures.extend(baseline_breaches(&suite, &results));
    assert!(failures.is_empty(), "\n{}", failures.join("\n"));
}
