import CalamoInput
import Testing

@Test func givenARecordingWhenFnIsPressedThenFnIsCapturedImmediately() {
    // Given
    var recorder = BindingRecorder()

    // When
    let reaction = recorder.handle(.flagsChanged(keyCode: Key.fn, modifiers: [], fnDown: true))

    // Then
    #expect(reaction == BindingRecorder.Reaction(verdict: .captured(.fn), swallowsEvent: true))
}

@Test func givenAccumulatedModifiersWhenTheFirstReleasesThenTheFullChordIsCaptured() {
    // Given
    var recorder = BindingRecorder()
    _ = recorder.handle(.flagsChanged(keyCode: Key.control, modifiers: [.control], fnDown: false))
    _ = recorder.handle(
        .flagsChanged(keyCode: Key.option, modifiers: [.control, .option], fnDown: false))

    // When
    let reaction = recorder.handle(
        .flagsChanged(keyCode: Key.option, modifiers: [.control], fnDown: false))

    // Then
    #expect(reaction.verdict == .captured(.chord([.control, .option])))
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

@Test func givenARecordingWhenEscapeIsPressedThenItIsCancelledAndTheKeySwallowed() {
    // Given
    var recorder = BindingRecorder()
    _ = recorder.handle(.flagsChanged(keyCode: Key.control, modifiers: [.control], fnDown: false))

    // When
    let reaction = recorder.handle(.keyDown(keyCode: Key.escape))

    // Then
    #expect(reaction == BindingRecorder.Reaction(verdict: .cancelled, swallowsEvent: true))
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
