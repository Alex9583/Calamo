//! The nominal cycle: `Capturing → Transcribing → Cleaning → Inserting →
//! Completed` — press, audio pushed, release, cleaned text inserted.

use crate::support::Harness;
use calamo_core::dictation::{DictationState, Language};
use calamo_core::dictionary::{Dictionary, DictionaryEntry};

#[test]
fn given_a_ready_engine_when_a_dictation_is_spoken_then_the_cleaned_text_is_inserted() {
    // Given
    let harness = Harness::ready();
    harness
        .transcription
        .replies_with("euh pousse la branche", Language::French);
    harness.cleanup.replies_with("Pousse la branche.");

    // When
    let id = harness.dictate(&[0.1, -0.2, 0.3]);

    // Then
    assert_eq!(
        harness.observer.wait_terminal(id),
        DictationState::Completed { degraded: false }
    );
    assert_eq!(harness.insertion.inserted_texts(), ["Pousse la branche."]);

    let transcription_calls = harness.transcription.calls();
    assert_eq!(transcription_calls.len(), 1, "one utterance transcribed");
    assert_eq!(
        transcription_calls[0].samples,
        [0.1, -0.2, 0.3],
        "the whole utterance reaches transcription"
    );

    let cleanup_calls = harness.cleanup.calls();
    assert_eq!(cleanup_calls.len(), 1, "one transcript cleaned");
    assert_eq!(cleanup_calls[0].transcript, "euh pousse la branche");
}

#[test]
fn given_a_dictionary_when_a_dictation_is_spoken_then_its_views_feed_every_stage() {
    // Given: a Dictionary loaded from the repository at construction
    let dictionary = Dictionary::new(vec![DictionaryEntry::with_aliases(
        "GitHub",
        ["guitte hub"],
    )])
    .unwrap();
    let harness = Harness::ready_with_dictionary(dictionary);
    harness
        .transcription
        .replies_with("pousse sur guitte hub", Language::French);
    harness.cleanup.replies_with("Pousse sur guitte hub.");

    // When
    let id = harness.dictate(&[0.1, 0.2]);
    harness.observer.wait_terminal(id);

    // Then: S1 — the boost list reaches transcription
    let transcription_calls = harness.transcription.calls();
    assert_eq!(transcription_calls[0].boost_list.len(), 1);
    assert_eq!(
        transcription_calls[0].boost_list[0].canonical_text(),
        "GitHub"
    );

    // S2 — the prompt glossary reaches cleanup
    assert_eq!(harness.cleanup.calls()[0].glossary, ["GitHub"]);

    // S3 — enforcement after cleanup, the only stage guaranteeing spellings
    assert_eq!(harness.insertion.inserted_texts(), ["Pousse sur GitHub."]);
}

#[test]
fn given_a_ready_engine_when_a_dictation_is_spoken_then_the_observer_sees_the_whole_cycle() {
    // Given
    let harness = Harness::ready();
    harness
        .transcription
        .replies_with("bonjour à tous", Language::French);

    // When
    let id = harness.dictate(&[0.1; 1600]);
    harness.observer.wait_terminal(id);

    // Then
    assert_eq!(
        harness.observer.states_of(id),
        [
            DictationState::Capturing,
            DictationState::Transcribing,
            DictationState::Cleaning,
            DictationState::Inserting,
            DictationState::Completed { degraded: false },
        ]
    );
}
