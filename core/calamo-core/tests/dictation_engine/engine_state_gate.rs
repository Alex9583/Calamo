//! EngineState gates dictation: no Dictation is born outside Ready — a press
//! yields an immediate, motivated refusal, never a silent wait.

use crate::support::{Harness, Observed};
use calamo_core::dictation::{DictationState, Language};
use calamo_core::engine::{EngineState, RefusalCause, UnavailabilityCause};

#[test]
fn given_a_loading_engine_when_the_hotkey_is_pressed_then_the_dictation_is_refused_as_engine_loading(
) {
    // Given
    let harness = Harness::loading();

    // When
    harness.engine.hotkey_pressed();

    // Then
    assert_eq!(harness.observer.refusals(), [RefusalCause::EngineLoading]);
    assert_eq!(
        harness.observer.born_dictations(),
        [],
        "no Dictation is born outside Ready"
    );
}

#[test]
fn given_an_unavailable_engine_when_the_hotkey_is_pressed_then_the_refusal_carries_the_cause() {
    // Given
    let harness = Harness::ready();
    harness
        .engine
        .mark_unavailable(UnavailabilityCause::ModelsMissing);

    // When
    harness.engine.hotkey_pressed();

    // Then
    assert_eq!(
        harness.observer.refusals(),
        [RefusalCause::EngineUnavailable {
            cause: UnavailabilityCause::ModelsMissing
        }]
    );
    assert_eq!(harness.observer.born_dictations(), []);
    assert!(
        harness
            .observer
            .events()
            .contains(&Observed::Engine(EngineState::Unavailable {
                cause: UnavailabilityCause::ModelsMissing
            })),
        "the observer heard the engine become unavailable"
    );
}

#[test]
fn given_models_arrived_when_the_engine_loads_again_then_a_press_is_refused_as_loading_once_more() {
    // Given: models were missing, their download just finished, warmup starts
    let harness = Harness::ready();
    harness
        .engine
        .mark_unavailable(UnavailabilityCause::ModelsMissing);
    harness.engine.mark_loading();

    // When
    harness.engine.hotkey_pressed();

    // Then
    assert_eq!(harness.observer.refusals(), [RefusalCause::EngineLoading]);
    assert!(
        harness
            .observer
            .events()
            .contains(&Observed::Engine(EngineState::Loading)),
        "the observer heard the engine load again"
    );
}

#[test]
fn given_a_refused_press_when_audio_is_pushed_anyway_then_no_ghost_audio_haunts_the_next_dictation(
) {
    // Given: a press refused while loading, with audio frames racing behind
    let harness = Harness::loading();
    harness.engine.hotkey_pressed();
    harness.engine.push_audio(&[0.9, 0.9, 0.9]);
    harness.engine.hotkey_released();

    // When: the engine becomes ready and a real dictation is spoken
    harness.engine.mark_ready();
    harness
        .transcription
        .replies_with("le vrai texte", Language::French);
    let id = harness.dictate(&[0.1, 0.2]);
    harness.observer.wait_terminal(id);

    // Then: only the real utterance ever reached transcription
    let calls = harness.transcription.calls();
    assert_eq!(calls.len(), 1);
    assert_eq!(calls[0].samples, [0.1, 0.2]);
}

#[test]
fn given_a_loading_engine_when_marked_ready_then_the_observer_sees_ready_and_a_press_starts_a_dictation(
) {
    // Given
    let harness = Harness::loading();

    // When
    harness.engine.mark_ready();
    harness.engine.hotkey_pressed();

    // Then
    let id = harness.observer.only_dictation();
    assert_eq!(
        harness.observer.events(),
        [
            Observed::Engine(EngineState::Ready),
            Observed::Dictation(id, DictationState::Capturing),
        ]
    );
}
