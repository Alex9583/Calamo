//! Loader for the cleanup golden vectors: literal thresholds, never
//! recomputed — takes and glossary stay owned by the referenced contract.

use serde::Deserialize;

#[derive(Deserialize)]
#[serde(deny_unknown_fields, rename_all = "camelCase")]
pub struct GoldenVectors {
    #[serde(rename = "_readme")]
    pub readme: String,
    pub contract: String,
    pub min_similarity_vs_clean: f64,
    pub max_takes_below_similarity: usize,
}

pub fn load(fixtures_dir: &std::path::Path) -> GoldenVectors {
    let path = fixtures_dir.join("cleanup-golden.json");
    let text = std::fs::read_to_string(&path)
        .unwrap_or_else(|e| panic!("unreadable {}: {e}", path.display()));
    serde_json::from_str(&text).unwrap_or_else(|e| panic!("malformed {}: {e}", path.display()))
}

pub fn validate(vectors: &GoldenVectors) -> Vec<String> {
    let mut issues = Vec::new();
    if !(0.0..=1.0).contains(&vectors.min_similarity_vs_clean) {
        issues.push(format!(
            "minSimilarityVsClean {} outside [0, 1]",
            vectors.min_similarity_vs_clean
        ));
    }
    if vectors.contract != "cleanup-contract.json" {
        issues.push(format!("contract reference drifted: {}", vectors.contract));
    }
    issues
}
