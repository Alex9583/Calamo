//! Through the exported object: the layout the shell builds engine config
//! and FluidAudio paths from is locked here.

use calamo_ffi::ModelStore;

#[test]
fn given_a_root_when_asking_paths_then_the_locked_layout_holds() {
    // Given
    let store = ModelStore::new("/tmp/store/models".into());

    // When
    let paths = store.paths();

    // Then
    assert_eq!(paths.asr_tdt_dir, "/tmp/store/models/parakeet-tdt-0.6b-v3");
    assert_eq!(
        paths.asr_ctc_dir,
        "/tmp/store/models/parakeet-ctc-110m-coreml"
    );
    assert_eq!(
        paths.cleanup_gguf,
        "/tmp/store/models/Qwen3.5-2B-Q4_K_M.gguf"
    );
}
