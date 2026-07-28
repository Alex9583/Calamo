//! Hot reload through the repository port: edits apply to the next
//! dictation; an invalid file keeps the previous dictionary active.

use crate::support::Harness;
use calamo_core::dictation::Language;
use calamo_core::dictionary::{Dictionary, DictionaryEntry};
use calamo_core::ports::DictionaryLoadError;

fn dictionary_of(canonical: &str) -> Dictionary {
    Dictionary::new(vec![DictionaryEntry::new(canonical)]).unwrap()
}

#[test]
fn given_an_edited_dictionary_when_reloaded_then_the_next_dictation_uses_it() {
    // Given
    let harness = Harness::ready_with_dictionary(dictionary_of("GitHub"));
    harness.repository.holds(dictionary_of("Jira"));

    // When
    let reloaded = harness.engine.reload_dictionary();

    // Then: the next dictation is boosted and enforced by the new dictionary
    assert_eq!(reloaded, Ok(()));
    harness
        .transcription
        .replies_with("ouvre jira", Language::French);
    let id = harness.dictate(&[0.1]);
    harness.observer.wait_terminal(id);

    assert_eq!(harness.insertion.inserted_texts(), ["ouvre Jira"]);
    let boost = &harness.transcription.calls()[0].boost_list;
    assert_eq!(boost[0].canonical_text(), "Jira");
}

#[test]
fn given_an_invalid_dictionary_file_when_reloaded_then_the_previous_dictionary_stays_active() {
    // Given
    let harness = Harness::ready_with_dictionary(dictionary_of("GitHub"));
    harness.repository.fails(Some(3), "expected `]`");

    // When
    let reloaded = harness.engine.reload_dictionary();

    // Then: the caller gets line and cause for its notification
    assert_eq!(
        reloaded,
        Err(DictionaryLoadError {
            line: Some(3),
            message: "expected `]`".to_string(),
        })
    );

    // Then: dictation still runs with the previous dictionary
    harness
        .transcription
        .replies_with("pousse sur github", Language::French);
    let id = harness.dictate(&[0.1]);
    harness.observer.wait_terminal(id);

    assert_eq!(harness.insertion.inserted_texts(), ["pousse sur GitHub"]);
}
