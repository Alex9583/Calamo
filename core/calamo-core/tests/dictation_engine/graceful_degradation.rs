//! A cleanup failure inserts the RawTranscript — spellings still enforced —
//! and the Dictation is Completed, never Failed.

use crate::support::Harness;
use calamo_core::dictation::{DictationState, Language};
use calamo_core::dictionary::{Dictionary, DictionaryEntry};

#[test]
fn given_a_failing_cleanup_when_a_dictation_is_spoken_then_the_enforced_verbatim_is_inserted_as_degraded(
) {
    // Given
    let dictionary = Dictionary::new(vec![DictionaryEntry::new("GitHub")]).unwrap();
    let harness = Harness::ready_with_dictionary(dictionary);
    harness
        .transcription
        .replies_with("euh pousse sur github", Language::French);
    harness.cleanup.fails("llm unavailable");

    // When
    let id = harness.dictate(&[0.4, 0.5]);

    // Then
    assert_eq!(
        harness.observer.wait_terminal(id),
        DictationState::Completed { degraded: true },
        "degraded is still Completed, never Failed"
    );
    assert_eq!(
        harness.insertion.inserted_texts(),
        ["euh pousse sur GitHub"],
        "verbatim inserted, spellings still guaranteed"
    );
    assert_eq!(harness.observer.states_of(id), degraded_trajectory());
}

/// The full pipeline still runs — degradation changes the payload, never the
/// states.
fn degraded_trajectory() -> [DictationState; 5] {
    [
        DictationState::Capturing,
        DictationState::Transcribing,
        DictationState::Cleaning,
        DictationState::Inserting,
        DictationState::Completed { degraded: true },
    ]
}
