//! Dropping the engine is the whole teardown: the pipeline thread is joined,
//! so no port clone survives to race the host process's exit.

use std::sync::Arc;

use crate::support::Harness;
use calamo_core::dictation::Language;

#[test]
fn given_a_dropped_engine_when_its_drop_returns_then_no_port_reference_survives() {
    // Given: an engine that has processed a dictation
    let harness = Harness::ready();
    harness
        .transcription
        .replies_with("un dernier texte", Language::French);
    let id = harness.dictate(&[0.1, 0.2]);
    harness.observer.wait_terminal(id);

    // When
    drop(harness.engine);

    // Then: the test doubles' only owners are the harness fields themselves
    assert_eq!(Arc::strong_count(&harness.cleanup), 1);
    assert_eq!(Arc::strong_count(&harness.transcription), 1);
    assert_eq!(Arc::strong_count(&harness.insertion), 1);
}
