import CalamoInput
import Testing

@Test func givenAnIdleMachineWhenTheHotkeyGoesDownThenTheDictationBeginsAndTheKeyIsSwallowed() {
    // Given
    var machine = PushToTalkMachine()

    // When
    let reaction = machine.handle(.hotkeyChanged(isDown: true))

    // Then
    #expect(reaction == HotkeyReaction(actions: [.beginDictation], swallowsEvent: true))
}

@Test func givenAHeldHotkeyWhenTheDownFlagRepeatsThenTheHoldContinuesSilently() {
    // Given
    var machine = PushToTalkMachine()
    _ = machine.handle(.hotkeyChanged(isDown: true))

    // When: a spurious repeat of the down flag
    let reaction = machine.handle(.hotkeyChanged(isDown: true))

    // Then
    #expect(reaction == HotkeyReaction(actions: [], swallowsEvent: true))
}

@Test func givenAHeldHotkeyWhenTheHotkeyGoesUpThenTheDictationEndsAndTheKeyIsSwallowed() {
    // Given
    var machine = PushToTalkMachine()
    _ = machine.handle(.hotkeyChanged(isDown: true))

    // When
    let reaction = machine.handle(.hotkeyChanged(isDown: false))

    // Then
    #expect(reaction == HotkeyReaction(actions: [.endDictation], swallowsEvent: true))
}

@Test func givenAnIdleMachineWhenAStrayHotkeyUpArrivesThenNothingHappensAndTheKeyIsSwallowed() {
    // Given
    var machine = PushToTalkMachine()

    // When: an up flag with no tracked hold, e.g. after a relaunch mid-press
    let reaction = machine.handle(.hotkeyChanged(isDown: false))

    // Then
    #expect(reaction == HotkeyReaction(actions: [], swallowsEvent: true))
}

@Test func givenAnAccidentalTapWhenTheHotkeyGoesDownThenUpThenOneDictationBeginsAndEnds() {
    // Given
    var machine = PushToTalkMachine()

    // When
    let onDown = machine.handle(.hotkeyChanged(isDown: true))
    let onUp = machine.handle(.hotkeyChanged(isDown: false))

    // Then: the core classifies the empty capture, the machine stays honest
    #expect(onDown.actions == [.beginDictation])
    #expect(onUp.actions == [.endDictation])
}

@Test func givenAnIdleMachineWhenAnotherKeyIsPressedThenItPassesThroughUntouched() {
    // Given
    var machine = PushToTalkMachine()

    // When
    let reaction = machine.handle(.otherKey)

    // Then
    #expect(reaction == HotkeyReaction(actions: [], swallowsEvent: false))
}

@Test func givenAHeldHotkeyWhenAnotherKeyIsPressedThenItPassesThroughAndTheHoldContinues() {
    // Given
    var machine = PushToTalkMachine()
    _ = machine.handle(.hotkeyChanged(isDown: true))

    // When
    let onOtherKey = machine.handle(.otherKey)
    let onRelease = machine.handle(.hotkeyChanged(isDown: false))

    // Then
    #expect(onOtherKey == HotkeyReaction(actions: [], swallowsEvent: false))
    #expect(onRelease.actions == [.endDictation])
}

@Test func givenAHeldHotkeyWhenTheTapIsDisabledByTimeoutThenItRearmsAndTheDictationEnds() {
    // Given
    var machine = PushToTalkMachine()
    _ = machine.handle(.hotkeyChanged(isDown: true))

    // When
    let reaction = machine.handle(.tapDisabled)

    // Then: the release may have been lost while the tap was off
    #expect(
        reaction == HotkeyReaction(actions: [.reenableTap, .endDictation], swallowsEvent: false))
}

@Test func givenAnIdleMachineWhenTheTapIsDisabledByTimeoutThenItOnlyRearms() {
    // Given
    var machine = PushToTalkMachine()

    // When
    let reaction = machine.handle(.tapDisabled)

    // Then
    #expect(reaction == HotkeyReaction(actions: [.reenableTap], swallowsEvent: false))
}

@Test func givenAHoldEndedByTimeoutWhenTheHotkeyGoesDownAgainThenANewDictationBegins() {
    // Given
    var machine = PushToTalkMachine()
    _ = machine.handle(.hotkeyChanged(isDown: true))
    _ = machine.handle(.tapDisabled)

    // When
    let reaction = machine.handle(.hotkeyChanged(isDown: true))

    // Then
    #expect(reaction == HotkeyReaction(actions: [.beginDictation], swallowsEvent: true))
}
