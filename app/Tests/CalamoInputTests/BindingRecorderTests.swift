import CalamoInput
import Testing

@Test func givenARecordingWhenFnIsPressedAndReleasedThenTheCaptureLandsOnTheRelease() {
    // Given
    var recorder = BindingRecorder()

    // When
    let press = recorder.handle(.flagsChanged(keyCode: Key.fn, modifiers: [], fnDown: true))
    let release = recorder.handle(.flagsChanged(keyCode: Key.fn, modifiers: [], fnDown: false))

    // Then
    #expect(press == BindingRecorder.Reaction(verdict: .recording, swallowsEvent: true))
    #expect(release == BindingRecorder.Reaction(verdict: .captured(.fn), swallowsEvent: true))
}

@Test func givenAccumulatedModifiersWhenAllReleaseThenTheFullChordIsCapturedOnTheLast() {
    // Given
    var recorder = BindingRecorder()
    _ = recorder.handle(.flagsChanged(keyCode: Key.control, modifiers: [.control], fnDown: false))
    _ = recorder.handle(
        .flagsChanged(keyCode: Key.option, modifiers: [.control, .option], fnDown: false))

    // When
    let firstRelease = recorder.handle(
        .flagsChanged(keyCode: Key.option, modifiers: [.control], fnDown: false))
    let lastRelease = recorder.handle(
        .flagsChanged(keyCode: Key.control, modifiers: [], fnDown: false))

    // Then
    #expect(firstRelease == BindingRecorder.Reaction(verdict: .recording, swallowsEvent: true))
    #expect(
        lastRelease
            == BindingRecorder.Reaction(
                verdict: .captured(.chord([.control, .option])), swallowsEvent: true))
}

@Test func givenGrowingModifiersWhenStillHeldThenTheRecordingContinuesAndSwallows() {
    // Given
    var recorder = BindingRecorder()

    // When
    let first = recorder.handle(
        .flagsChanged(keyCode: Key.control, modifiers: [.control], fnDown: false))
    let second = recorder.handle(
        .flagsChanged(keyCode: Key.option, modifiers: [.control, .option], fnDown: false))

    // Then
    #expect(first == BindingRecorder.Reaction(verdict: .recording, swallowsEvent: true))
    #expect(second == BindingRecorder.Reaction(verdict: .recording, swallowsEvent: true))
}

@Test func givenAStrayReleaseBeforeAnyPressWhenRecordingThenNothingIsCaptured() {
    // Given: a modifier held from before the recording started
    var recorder = BindingRecorder()

    // When
    let reaction = recorder.handle(.flagsChanged(keyCode: Key.shift, modifiers: [], fnDown: false))

    // Then
    #expect(reaction.verdict == .recording)
}

@Test func givenNothingHeldWhenEscapeIsPressedThenItIsCancelledAndTheKeySwallowed() {
    // Given
    var recorder = BindingRecorder()

    // When
    let reaction = recorder.handle(.keyDown(keyCode: Key.escape))

    // Then
    #expect(reaction == BindingRecorder.Reaction(verdict: .cancelled, swallowsEvent: true))
}

@Test func givenAHeldModifierWhenEscapeIsPressedThenTheCancelWaitsForTheRelease() {
    // Given
    var recorder = BindingRecorder()
    _ = recorder.handle(.flagsChanged(keyCode: Key.control, modifiers: [.control], fnDown: false))

    // When
    let escape = recorder.handle(.keyDown(keyCode: Key.escape))
    let release = recorder.handle(.flagsChanged(keyCode: Key.control, modifiers: [], fnDown: false))

    // Then
    #expect(escape == BindingRecorder.Reaction(verdict: .recording, swallowsEvent: true))
    #expect(release == BindingRecorder.Reaction(verdict: .cancelled, swallowsEvent: true))
}

@Test func givenARecordingWhenPlainKeysArriveThenTheyPassThroughUntouched() {
    // Given
    var recorder = BindingRecorder()

    // When
    let down = recorder.handle(.keyDown(keyCode: Key.letter))
    let up = recorder.handle(.keyUp(keyCode: Key.letter))

    // Then
    #expect(down == BindingRecorder.Reaction(verdict: .recording, swallowsEvent: false))
    #expect(up == BindingRecorder.Reaction(verdict: .recording, swallowsEvent: false))
}

@Test func givenARecordingWhenTheTapDiesThenItIsCancelledWithoutSwallowing() {
    // Given
    var recorder = BindingRecorder()

    // When
    let reaction = recorder.handle(.tapDisabled)

    // Then
    #expect(reaction == BindingRecorder.Reaction(verdict: .cancelled, swallowsEvent: false))
}

@Test func givenAPressedFnWhenEscapeFollowsBeforeTheReleaseThenTheCaptureIsAborted() {
    // Given: Fn decided the capture but the verdict has not landed yet
    var recorder = BindingRecorder()
    _ = recorder.handle(.flagsChanged(keyCode: Key.fn, modifiers: [], fnDown: true))

    // When
    let escape = recorder.handle(.keyDown(keyCode: Key.escape))
    let release = recorder.handle(.flagsChanged(keyCode: Key.fn, modifiers: [], fnDown: false))

    // Then
    #expect(escape == BindingRecorder.Reaction(verdict: .recording, swallowsEvent: true))
    #expect(release == BindingRecorder.Reaction(verdict: .cancelled, swallowsEvent: true))
}

@Test func givenAPressedFnWhenTheTapDiesThenThePendingCaptureIsStillDelivered() {
    // Given: Fn decided the capture but its release can never arrive
    var recorder = BindingRecorder()
    _ = recorder.handle(.flagsChanged(keyCode: Key.fn, modifiers: [], fnDown: true))

    // When
    let reaction = recorder.handle(.tapDisabled)

    // Then
    #expect(reaction == BindingRecorder.Reaction(verdict: .captured(.fn), swallowsEvent: false))
}
