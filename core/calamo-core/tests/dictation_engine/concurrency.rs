//! Concurrency: at most one Dictation in the pipeline and one in capture;
//! a press during processing starts capturing immediately; insertions land
//! strictly in release order.

use crate::support::{Gate, Harness, Observed};
use calamo_core::dictation::{DictationId, DictationState, Language};
use calamo_core::engine::RefusalCause;

/// Waits until the gated transcription call has started.
fn wait_transcribing(harness: &Harness, id: DictationId) {
    harness.observer.wait_until("transcribing", |events| {
        events
            .iter()
            .any(|e| matches!(e, Observed::Dictation(seen, DictationState::Transcribing) if *seen == id))
    });
}

#[test]
fn given_a_dictation_processing_when_the_hotkey_is_pressed_then_the_next_capture_starts_immediately(
) {
    // Given: a dictation held mid-transcription — the pipeline is busy, the
    // microphone is free
    let harness = Harness::ready();
    let gate = Gate::closed();
    harness
        .transcription
        .replies_after(&gate, "la première phrase", Language::French);
    let first = harness.dictate(&[0.1]);
    wait_transcribing(&harness, first);

    // When
    harness.engine.hotkey_pressed();

    // Then: the second dictation is already capturing while the first is
    // still being processed
    let born = harness.observer.born_dictations();
    assert_eq!(born.len(), 2, "the press was neither refused nor queued");
    assert_eq!(
        harness.observer.states_of(first).last(),
        Some(&DictationState::Transcribing),
        "the first dictation is still in the pipeline"
    );

    gate.open();
    harness.engine.hotkey_released();
    harness.observer.wait_terminal(born[1]);
}

#[test]
fn given_two_dictations_in_flight_when_both_complete_then_insertions_follow_release_order() {
    // Given: the first dictation is slow to transcribe, the second is spoken
    // and released while the first still processes
    let harness = Harness::ready();
    let gate = Gate::closed();
    harness
        .transcription
        .replies_after(&gate, "la première phrase", Language::French);
    harness
        .transcription
        .replies_with("la seconde phrase", Language::French);
    let first = harness.dictate(&[0.1]);
    wait_transcribing(&harness, first);
    let second = harness.dictate(&[0.2]);

    // When
    gate.open();
    harness.observer.wait_terminal(second);

    // Then: strictly the release order, never a race for the cursor
    assert_eq!(
        harness.insertion.inserted_texts(),
        ["la première phrase", "la seconde phrase"]
    );
    assert_eq!(
        harness.observer.wait_terminal(first),
        DictationState::Completed { degraded: false }
    );
}

#[test]
fn given_one_processing_and_one_waiting_when_the_hotkey_is_pressed_then_it_is_refused() {
    // Given: a first dictation held mid-transcription, a second captured and
    // released behind it — both slots taken
    let harness = Harness::ready();
    let gate = Gate::closed();
    harness
        .transcription
        .replies_after(&gate, "la première phrase", Language::French);
    harness
        .transcription
        .replies_with("la seconde phrase", Language::French);
    let first = harness.dictate(&[0.1]);
    wait_transcribing(&harness, first);
    let second = harness.dictate(&[0.2]);

    // When: a third press while both slots are taken
    harness.engine.hotkey_pressed();

    // Then: refused, motivated — never a silent wait
    assert_eq!(harness.observer.refusals(), [RefusalCause::PipelineBusy]);
    assert_eq!(harness.observer.born_dictations(), [first, second]);

    // And once the pipeline drains, both complete in order
    gate.open();
    harness.observer.wait_terminal(second);
    assert_eq!(
        harness.insertion.inserted_texts(),
        ["la première phrase", "la seconde phrase"]
    );
}

#[test]
fn given_a_capture_in_progress_when_the_hotkey_repeats_then_the_capture_continues_undisturbed() {
    // Given
    let harness = Harness::ready();
    harness
        .transcription
        .replies_with("un seul texte", Language::French);
    harness.engine.hotkey_pressed();
    harness.engine.push_audio(&[0.1]);

    // When: a parasitic repeat press lands mid-capture
    harness.engine.hotkey_pressed();
    harness.engine.push_audio(&[0.2]);
    harness.engine.hotkey_released();

    // Then: one dictation, no refusal, the whole utterance intact
    let id = harness.observer.only_dictation();
    assert_eq!(harness.observer.refusals(), []);
    harness.observer.wait_terminal(id);
    assert_eq!(harness.transcription.calls()[0].samples, [0.1, 0.2]);
}
