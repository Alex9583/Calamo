// Pins the event → overlay/sound mapping the AppKit glue renders verbatim.
import CalamoCore
import CalamoFeedback
import Testing

@Test func givenAnIdleMachineWhenCaptureBeginsThenTheWaveformShowsAndTheStartSoundPlays() {
    // Given
    var machine = FeedbackMachine()

    // When
    let reaction = machine.handle(.capturing)

    // Then
    #expect(reaction == FeedbackReaction(step: OverlayStep(display: .waveform), sound: .captureStart))
}

@Test func givenACapturingDictationWhenTranscriptionBeginsThenTheWaitShowsAndTheEndSoundPlays() {
    // Given
    var machine = FeedbackMachine()
    _ = machine.handle(.capturing)

    // When
    let reaction = machine.handle(.transcribing)

    // Then
    #expect(reaction == FeedbackReaction(step: OverlayStep(display: .waiting), sound: .captureEnd))
}

@Test(arguments: [DictationState.cleaning, .inserting])
func givenAProcessingDictationWhenItAdvancesThenTheWaitContinuesSilently(state: DictationState) {
    // Given
    var machine = FeedbackMachine()
    _ = machine.handle(.capturing)
    _ = machine.handle(.transcribing)

    // When
    let reaction = machine.handle(state)

    // Then
    #expect(reaction == FeedbackReaction(step: OverlayStep(display: .waiting), sound: nil))
}

@Test func givenAProcessingDictationWhenItCompletesCleanThenThePillDissolvesImmediately() {
    // Given
    var machine = FeedbackMachine()
    _ = machine.handle(.capturing)
    _ = machine.handle(.transcribing)
    _ = machine.handle(.inserting)

    // When
    let reaction = machine.handle(.completed(degraded: false))

    // Then
    #expect(reaction == FeedbackReaction(step: OverlayStep(display: .hidden), sound: nil))
}

@Test func givenAProcessingDictationWhenItCompletesDegradedThenTheNoticeShowsForAboutASecond() {
    // Given
    var machine = FeedbackMachine()
    _ = machine.handle(.capturing)
    _ = machine.handle(.transcribing)

    // When
    let reaction = machine.handle(.completed(degraded: true))

    // Then
    let step = OverlayStep(display: .notice("Inserted without cleanup"), dissolveAfter: 1.0)
    #expect(reaction == FeedbackReaction(step: step, sound: nil))
}

@Test(arguments: [
    (FailureReason.emptyDictation, "Nothing heard"),
    (FailureReason.secureField, "Secure field — dictation refused"),
    (FailureReason.transcriptionFailed, "Transcription failed"),
    (FailureReason.insertionFailed, "Insertion failed"),
    (FailureReason.micUnavailable, "Microphone unavailable"),
    (FailureReason.permissionRevoked, "Microphone access revoked"),
])
func givenAProcessingDictationWhenItFailsThenItsShortCauseShowsBriefly(
    scenario: (FailureReason, String)
) {
    // Given
    var machine = FeedbackMachine()
    _ = machine.handle(.capturing)
    _ = machine.handle(.transcribing)

    // When
    let reaction = machine.handle(.failed(reason: scenario.0))

    // Then
    let step = OverlayStep(display: .notice(scenario.1), dissolveAfter: 1.5)
    #expect(reaction.step == step)
    #expect(reaction.sound == nil)
}

@Test func givenAProcessingDictationWhenInsertionFailsEntirelyThenTheManualPasteNoticeIsRaised() {
    // Given
    var machine = FeedbackMachine()
    _ = machine.handle(.capturing)
    _ = machine.handle(.inserting)

    // When
    let reaction = machine.handle(.failed(reason: .insertionFailed))

    // Then: the text stayed on the pasteboard — an action is required
    let notice = UserNotice(
        title: "Insertion failed", body: "Text copied — paste with ⌘V",
        identifier: "calamo.insertion-last-resort")
    #expect(reaction.notice == notice)
}

@Test(arguments: [
    FailureReason.emptyDictation, .secureField, .transcriptionFailed, .micUnavailable,
    .permissionRevoked,
])
func givenAnyOtherFailureWhenItIsReportedThenNoNotificationIsRaised(reason: FailureReason) {
    // Given
    var machine = FeedbackMachine()
    _ = machine.handle(.capturing)

    // When
    let reaction = machine.handle(.failed(reason: reason))

    // Then: no action required — the overlay notice is the whole feedback
    #expect(reaction.notice == nil)
}

@Test func givenACapturingDictationWhenTheMicFailsThenTheEndSoundStillPlays() {
    // Given
    var machine = FeedbackMachine()
    _ = machine.handle(.capturing)

    // When
    let reaction = machine.handle(.failed(reason: .micUnavailable))

    // Then
    #expect(reaction.sound == .captureEnd)
}

@Test(arguments: [
    (RefusalCause.engineLoading, "Models loading…"),
    (RefusalCause.engineUnavailable(cause: .modelsMissing), "Models missing"),
    (RefusalCause.pipelineBusy, "Still processing…"),
])
func givenAnyDictationAttemptWhenItIsRefusedThenTheCauseShowsBrieflyWithoutASound(
    scenario: (RefusalCause, String)
) {
    // Given
    let machine = FeedbackMachine()

    // When
    let reaction = machine.handle(refusal: scenario.0)

    // Then
    let step = OverlayStep(display: .notice(scenario.1), dissolveAfter: 1.5)
    #expect(reaction == FeedbackReaction(step: step, sound: nil))
}

@Test func givenAProcessingDictationWhenANewPressIsRefusedThenTheNoticeRevertsToTheWait() {
    // Given
    var machine = FeedbackMachine()
    _ = machine.handle(.capturing)
    _ = machine.handle(.transcribing)

    // When
    let reaction = machine.handle(refusal: .pipelineBusy)

    // Then
    let step = OverlayStep(
        display: .notice("Still processing…"), dissolveAfter: 1.5, revertsTo: .waiting
    )
    #expect(reaction == FeedbackReaction(step: step, sound: nil))
}

@Test func givenAPostUpdateColdStartWhenAPressIsRefusedDuringLoadingThenTheNoticeExplainsIt() {
    // Given
    let machine = FeedbackMachine(coldStart: .postUpdate)

    // When
    let reaction = machine.handle(refusal: .engineLoading)

    // Then: same message as the menu bar line
    let step = OverlayStep(
        display: .notice("Optimizing after update… (~1 min, once)"), dissolveAfter: 1.5)
    #expect(reaction == FeedbackReaction(step: step, sound: nil))
}

@Test func givenAPostUpdateColdStartWhenTheEngineWasReadyOnceThenALaterRefusalSaysLoading() {
    // Given: the post-update compile completed; a redownload cycle follows
    var machine = FeedbackMachine(coldStart: .postUpdate)
    machine.handle(engine: .ready)
    machine.handle(engine: .loading)

    // When
    let reaction = machine.handle(refusal: .engineLoading)

    // Then
    #expect(reaction.step.display == .notice("Models loading…"))
}

@Test func givenACompletedDictationWhenANewCaptureBeginsThenTheStartSoundPlaysAgain() {
    // Given
    var machine = FeedbackMachine()
    _ = machine.handle(.capturing)
    _ = machine.handle(.transcribing)
    _ = machine.handle(.completed(degraded: false))

    // When
    let reaction = machine.handle(.capturing)

    // Then
    #expect(reaction == FeedbackReaction(step: OverlayStep(display: .waveform), sound: .captureStart))
}
