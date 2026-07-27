//! Shared loader for the cleanup contract vectors and the private corpus
//! manifest — used by the always-on guard and the feature-gated harness.

use serde::Deserialize;
use std::path::{Path, PathBuf};

#[derive(Deserialize)]
#[serde(deny_unknown_fields, rename_all = "camelCase")]
pub struct Contract {
    #[serde(rename = "_readme")]
    pub readme: String,
    pub manifest: String,
    pub glossary: Glossary,
    pub corpus: Vec<CorpusVector>,
    pub synthetic: Vec<SyntheticVector>,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields, rename_all = "camelCase")]
pub struct Glossary {
    pub spoken: Vec<String>,
    pub never_spoken: Vec<String>,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields, rename_all = "camelCase")]
pub struct CorpusVector {
    pub id: String,
    pub identical: bool,
    pub max_word_error_rate: Option<f64>,
    #[serde(default)]
    pub forbidden: Vec<String>,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields, rename_all = "camelCase")]
pub struct SyntheticVector {
    pub id: String,
    #[serde(default = "french")]
    pub language: VectorLanguage,
    pub verbatim: String,
    pub expected: Option<String>,
    #[serde(default)]
    pub must_contain: Vec<String>,
    #[serde(default)]
    pub must_not_contain: Vec<String>,
}

#[derive(Deserialize, Clone, Copy)]
#[serde(rename_all = "lowercase")]
pub enum VectorLanguage {
    Fr,
    En,
    Mixed,
}

fn french() -> VectorLanguage {
    VectorLanguage::Fr
}

/// Lenient on purpose: the private manifest carries recording metadata the
/// contract does not care about.
#[derive(Deserialize)]
pub struct Manifest {
    pub boosting: Boosting,
    #[serde(rename = "fixture")]
    pub fixtures: Vec<Fixture>,
}

#[derive(Deserialize)]
pub struct Boosting {
    pub terms_in_fixtures: Vec<String>,
    pub terms_extra: Vec<String>,
}

#[derive(Deserialize, Clone)]
pub struct Fixture {
    pub id: String,
    pub lang: VectorLanguage,
    pub verbatim: String,
    pub clean: String,
}

impl Glossary {
    /// Prompt injection order: spoken terms first, then the never-spoken
    /// false-positive sentinels — the order the prototype validated.
    pub fn terms(&self) -> Vec<String> {
        self.spoken
            .iter()
            .chain(&self.never_spoken)
            .cloned()
            .collect()
    }
}

impl Manifest {
    pub fn fixture(&self, id: &str) -> Option<&Fixture> {
        self.fixtures.iter().find(|f| f.id == id)
    }
}

pub fn fixtures_dir() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("../../fixtures")
}

pub fn load_contract() -> Contract {
    let path = fixtures_dir().join("cleanup-contract.json");
    let text = std::fs::read_to_string(&path)
        .unwrap_or_else(|e| panic!("unreadable {}: {e}", path.display()));
    serde_json::from_str(&text).unwrap_or_else(|e| panic!("malformed {}: {e}", path.display()))
}

/// `None` only when the private corpus is absent (any machine but the
/// reference one); a present-but-malformed manifest fails loudly.
pub fn load_manifest(contract: &Contract) -> Option<Manifest> {
    let path = fixtures_dir().join(&contract.manifest);
    let text = std::fs::read_to_string(&path).ok()?;
    Some(toml::from_str(&text).unwrap_or_else(|e| panic!("malformed {}: {e}", path.display())))
}

pub fn validate(contract: &Contract, manifest: Option<&Manifest>) -> Vec<String> {
    let mut issues = glossary_issues(&contract.glossary);
    issues.extend(corpus_issues(&contract.corpus));
    issues.extend(synthetic_issues(&contract.synthetic));
    if let Some(manifest) = manifest {
        issues.extend(manifest_issues(contract, manifest));
    }
    issues
}

fn glossary_issues(glossary: &Glossary) -> Vec<String> {
    let mut issues = Vec::new();
    if glossary.spoken.is_empty() {
        issues.push("empty spoken glossary".into());
    }
    for term in &glossary.never_spoken {
        if glossary.spoken.contains(term) {
            issues.push(format!("glossary term both spoken and neverSpoken: {term}"));
        }
    }
    issues
}

fn corpus_issues(corpus: &[CorpusVector]) -> Vec<String> {
    let mut issues = Vec::new();
    let mut seen = std::collections::HashSet::new();
    for vector in corpus {
        if !seen.insert(&vector.id) {
            issues.push(format!("duplicate corpus id: {}", vector.id));
        }
        if !vector.identical && vector.max_word_error_rate.is_none() {
            issues.push(format!(
                "corpus {}: neither identical nor maxWordErrorRate",
                vector.id
            ));
        }
        if vector.forbidden.iter().any(|f| f.is_empty()) {
            issues.push(format!("corpus {}: empty forbidden string", vector.id));
        }
    }
    issues
}

fn synthetic_issues(synthetic: &[SyntheticVector]) -> Vec<String> {
    let mut issues = Vec::new();
    for vector in synthetic {
        if vector.verbatim.is_empty() {
            issues.push(format!("synthetic {}: empty verbatim", vector.id));
        }
        if vector.expected.is_none()
            && vector.must_contain.is_empty()
            && vector.must_not_contain.is_empty()
        {
            issues.push(format!("synthetic {}: no expectation at all", vector.id));
        }
    }
    issues
}

fn manifest_issues(contract: &Contract, manifest: &Manifest) -> Vec<String> {
    let mut issues = Vec::new();
    for vector in &contract.corpus {
        if manifest.fixture(&vector.id).is_none() {
            issues.push(format!("corpus {} not in the manifest", vector.id));
        }
    }
    if contract.corpus.len() != manifest.fixtures.len() {
        issues.push("corpus vectors do not cover every manifest take".into());
    }
    if contract.glossary.spoken != manifest.boosting.terms_in_fixtures
        || contract.glossary.never_spoken != manifest.boosting.terms_extra
    {
        issues.push("glossary drifted from the manifest's term lists".into());
    }
    issues
}
