//! Always-on guard for the cleanup golden suite: the vectors file and the
//! metric layer must stay honest in CI, where the feature-gated suite
//! itself never runs.

#[path = "contract_data/mod.rs"]
#[allow(dead_code)]
mod contract_data;
#[path = "golden_data/mod.rs"]
#[allow(dead_code)]
mod golden_data;
#[path = "text_metrics/mod.rs"]
#[allow(dead_code)]
mod text_metrics;

use text_metrics::{levenshtein_similarity04, term_count, term_exact};

#[test]
fn given_the_committed_golden_vectors_file_when_parsed_then_it_is_well_formed() {
    // When: parsing panics on unreadable or malformed data
    let vectors = golden_data::load(&contract_data::fixtures_dir());
    let issues = golden_data::validate(&vectors);

    // Then
    assert!(
        issues.is_empty(),
        "invalid cleanup-golden.json:\n{}",
        issues.join("\n")
    );
}

#[test]
fn given_digit_and_spelled_number_variants_when_compared_then_similarity_is_perfect() {
    // Given: the manifest spells numbers out while the ASR emits digits
    let spelled = "Le mardi quinze juillet à quatorze heures trente.";
    let digits = "le mardi 15 juillet à 14h30";

    // Then
    assert_eq!(levenshtein_similarity04(spelled, digits), 1.0);
}

#[test]
fn given_english_time_variants_when_compared_then_similarity_is_perfect() {
    // Given
    let spelled = "Friday, June twentieth at three thirty p.m.";
    let digits = "Friday June 20 at 3:30 pm";

    // Then
    assert_eq!(levenshtein_similarity04(spelled, digits), 1.0);
}

#[test]
fn given_hesitation_fillers_when_compared_then_they_do_not_count() {
    // Given
    let with_fillers = "Euh... alors pour le, um, rapport mensuel";
    let without = "alors pour le rapport mensuel";

    // Then
    assert_eq!(levenshtein_similarity04(with_fillers, without), 1.0);
}

#[test]
fn given_a_dropped_clause_when_compared_then_similarity_falls_below_one() {
    // Given: fr-04's known cleanup defect, an abandoned sentence start kept
    let kept =
        "Il faut qu'on parle du budget avant vendredi. Je pense que... enfin bref, appelle-moi.";
    let expected = "Il faut qu'on parle du budget avant vendredi. Bref, appelle-moi.";

    // When
    let similarity = levenshtein_similarity04(kept, expected);

    // Then
    assert!(similarity < 0.95, "similarity {similarity}");
    assert!(similarity > 0.5, "similarity {similarity}");
}

#[test]
fn given_empty_texts_when_compared_then_similarity_is_perfect() {
    // Then
    assert_eq!(levenshtein_similarity04("", ""), 1.0);
    assert_eq!(levenshtein_similarity04("Euh.", ""), 1.0);
}

#[test]
fn given_exact_spellings_when_searched_then_only_case_and_boundary_matches_count() {
    // Then: case-sensitive at word boundaries
    assert!(term_exact("QA", "et si la QA est OK on push"));
    assert!(term_exact(
        "pull request",
        "merger ta pull request avant la démo"
    ));
    assert!(term_exact("adapter", "on garde l'adapter Stripe"));
    assert!(!term_exact("Design System", "le design system est cassé"));
    assert!(!term_exact("merge", "pense à merger ta pull request"));
    assert!(!term_exact("prod", "la production est en panne"));
    assert!(!term_exact("PR", "c'est pour demain"));
}

#[test]
fn given_repeated_occurrences_when_counted_then_each_boundary_match_counts() {
    // Then: same alphabet as term_present, occurrences instead of presence
    assert_eq!(term_count("GitHub", "GitHub GitHub"), 2);
    assert_eq!(term_count("github", "regarde le repo sur GitHub"), 1);
    assert_eq!(term_count("merge", "pense à merger ta pull request"), 0);
    assert_eq!(term_count("git hub", "le git hub de l'équipe"), 1);
    assert_eq!(term_count("Calamo", ""), 0);
}
