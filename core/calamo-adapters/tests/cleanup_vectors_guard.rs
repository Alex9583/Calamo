//! Always-on guard: a malformed vectors file must fail loudly here, in CI —
//! otherwise the feature-gated contract would just skip it in silence.

// dead_code: the shared module is recompiled per test target; this one only
// validates shape and never runs the vectors.
#[path = "contract_data/mod.rs"]
#[allow(dead_code)]
mod contract_data;

#[test]
fn given_the_committed_vectors_file_when_parsed_then_it_is_well_formed() {
    // When: parsing panics on unreadable or malformed data
    let contract = contract_data::load_contract();
    let issues = contract_data::validate(&contract, None);

    // Then
    assert!(
        issues.is_empty(),
        "invalid cleanup-contract.json:\n{}",
        issues.join("\n")
    );
}

#[test]
fn given_the_private_manifest_when_present_then_the_vectors_and_glossary_cover_it() {
    // Given: only the reference machine has the corpus
    let contract = contract_data::load_contract();
    let Some(manifest) = contract_data::load_manifest(&contract) else {
        eprintln!("SKIP: private corpus manifest absent");
        return;
    };

    // When
    let issues = contract_data::validate(&contract, Some(&manifest));

    // Then
    assert!(
        issues.is_empty(),
        "vectors drifted from the manifest:\n{}",
        issues.join("\n")
    );
}
