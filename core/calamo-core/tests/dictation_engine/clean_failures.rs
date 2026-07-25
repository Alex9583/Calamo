//! Clean failures: nothing is ever inserted on an upstream failure, and every
//! failure reaches the observer with its reason — never a silent one.

use crate::support::Harness;
use calamo_core::dictation::{DictationState, FailureReason, Language};
use calamo_core::engine::CaptureIncident;

#[test]
fn given_no_audio_when_the_hotkey_is_released_then_the_dictation_fails_as_empty() {
    // Given: an accidental press — released without a single audio frame
    let harness = Harness::ready();
    harness.engine.hotkey_pressed();

    // When
    harness.engine.hotkey_released();

    // Then
    let id = harness.observer.only_dictation();
    assert_eq!(
        harness.observer.wait_terminal(id),
        DictationState::Failed {
            reason: FailureReason::EmptyDictation
        }
    );
    assert_eq!(
        harness.transcription.calls().len(),
        0,
        "nothing to transcribe"
    );
    assert_eq!(harness.insertion.inserted_texts(), [""; 0]);
}

#[test]
fn given_only_silence_when_a_dictation_is_spoken_then_it_fails_as_empty_and_nothing_is_inserted() {
    // Given: audio was captured, but speech recognition heard nothing
    let harness = Harness::ready();
    harness.transcription.replies_with("  ", Language::French);

    // When
    let id = harness.dictate(&[0.0; 1600]);

    // Then
    assert_eq!(
        harness.observer.wait_terminal(id),
        DictationState::Failed {
            reason: FailureReason::EmptyDictation
        }
    );
    assert_eq!(harness.cleanup.calls().len(), 0, "nothing to clean");
    assert_eq!(harness.insertion.inserted_texts(), [""; 0]);
}

#[test]
fn given_a_secure_field_when_a_dictation_is_spoken_then_the_insertion_is_refused() {
    // Given: the focused field is a password field
    let harness = Harness::ready();
    harness
        .transcription
        .replies_with("mon mot de passe", Language::French);
    harness.insertion.refuses_secure_field();

    // When
    let id = harness.dictate(&[0.3, 0.1]);

    // Then
    assert_eq!(
        harness.observer.wait_terminal(id),
        DictationState::Failed {
            reason: FailureReason::SecureField
        }
    );
    assert_eq!(harness.insertion.inserted_texts(), [""; 0]);
}

#[test]
fn given_a_broken_insertion_when_a_dictation_is_spoken_then_it_fails_as_insertion_failed() {
    // Given
    let harness = Harness::ready();
    harness
        .transcription
        .replies_with("un texte propre", Language::French);
    harness.insertion.fails("paste never landed");

    // When
    let id = harness.dictate(&[0.3, 0.1]);

    // Then
    assert_eq!(
        harness.observer.wait_terminal(id),
        DictationState::Failed {
            reason: FailureReason::InsertionFailed
        }
    );
}

#[test]
fn given_the_mic_vanishes_mid_capture_when_reported_then_the_dictation_fails_as_mic_unavailable() {
    // Given: a capture in progress
    let harness = Harness::ready();
    harness.engine.hotkey_pressed();
    harness.engine.push_audio(&[0.2, 0.2]);

    // When: the shell reports the incident, then the key is released
    harness
        .engine
        .capture_failed(CaptureIncident::MicUnavailable);
    harness.engine.hotkey_released();

    // Then
    let id = harness.observer.only_dictation();
    assert_eq!(
        harness.observer.states_of(id),
        [
            DictationState::Capturing,
            DictationState::Failed {
                reason: FailureReason::MicUnavailable
            }
        ]
    );
    assert_eq!(
        harness.transcription.calls().len(),
        0,
        "nothing reaches the pipeline"
    );
}

#[test]
fn given_the_permission_is_revoked_mid_capture_when_reported_then_the_dictation_fails_as_permission_revoked(
) {
    // Given
    let harness = Harness::ready();
    harness.engine.hotkey_pressed();

    // When
    harness
        .engine
        .capture_failed(CaptureIncident::PermissionRevoked);

    // Then
    let id = harness.observer.only_dictation();
    assert_eq!(
        harness.observer.wait_terminal(id),
        DictationState::Failed {
            reason: FailureReason::PermissionRevoked
        }
    );
}

#[test]
fn given_a_failing_transcription_when_a_dictation_is_spoken_then_it_fails_and_nothing_is_inserted()
{
    // Given
    let harness = Harness::ready();
    harness.transcription.fails("asr crashed");

    // When
    let id = harness.dictate(&[0.1, 0.2]);

    // Then
    assert_eq!(
        harness.observer.wait_terminal(id),
        DictationState::Failed {
            reason: FailureReason::TranscriptionFailed
        }
    );
    assert_eq!(harness.insertion.inserted_texts(), [""; 0]);
    assert_eq!(harness.cleanup.calls().len(), 0, "nothing to clean either");
}
