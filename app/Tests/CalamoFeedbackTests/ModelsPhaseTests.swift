// Pins the wizard's Models-step narrative: downloading → optimizing → ready.
import CalamoCore
import CalamoFeedback
import Testing

@Test func givenTheStoreStillConvergingWhenDerivingThenThePhaseIsDownloading() {
    // Given
    let progress = ModelDownloadProgress(ready: 1, total: 3)

    // When
    let phase = ModelsPhase.derive(engine: .loading, download: progress, ensureFinished: false)

    // Then
    #expect(phase == .downloading(progress))
}

@Test func givenNoProgressReportYetWhenDerivingThenThePhaseIsDownloadingIndeterminate() {
    // When
    let phase = ModelsPhase.derive(engine: .loading, download: nil, ensureFinished: false)

    // Then
    #expect(phase == .downloading(nil))
}

@Test func givenTheStoreConvergedWhenTheEngineStillLoadsThenThePhaseIsOptimizing() {
    // When: downloads done, the models still compile for this Mac
    let phase = ModelsPhase.derive(engine: .loading, download: nil, ensureFinished: true)

    // Then
    #expect(phase == .optimizing)
}

@Test(arguments: [false, true])
func givenAReadyEngineWhenDerivingThenThePhaseIsReady(ensureFinished: Bool) {
    // When
    let phase = ModelsPhase.derive(engine: .ready, download: nil, ensureFinished: ensureFinished)

    // Then
    #expect(phase == .ready)
}

@Test func givenAnUnavailableEngineWhenDerivingThenThePhaseIsFailed() {
    // When
    let phase = ModelsPhase.derive(
        engine: .unavailable(cause: .modelsMissing), download: nil, ensureFinished: true)

    // Then
    #expect(phase == .failed)
}
