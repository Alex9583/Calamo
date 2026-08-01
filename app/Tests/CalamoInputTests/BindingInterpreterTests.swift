import CalamoInput
import Testing

@Test func givenTheFnBindingWhenTheFnFlagTogglesThenTheHotkeyFollowsIt() {
    // Given
    var interpreter = BindingInterpreter(binding: .fn)

    // When
    let down = interpreter.interpret(.flagsChanged(keyCode: Key.fn, modifiers: [], fnDown: true))
    let up = interpreter.interpret(.flagsChanged(keyCode: Key.fn, modifiers: [], fnDown: false))

    // Then
    #expect(down == .hotkeyChanged(isDown: true))
    #expect(up == .hotkeyChanged(isDown: false))
}

@Test func givenTheFnBindingWhenPlainModifiersChangeThenTheyPassAsOtherKeys() {
    // Given
    var interpreter = BindingInterpreter(binding: .fn)

    // When
    let event = interpreter.interpret(
        .flagsChanged(keyCode: Key.control, modifiers: [.control], fnDown: false))

    // Then
    #expect(event == .otherKey)
}

@Test func givenAChordBindingWhenTheLastModifierJoinsThenTheHotkeyGoesDownOnce() {
    // Given
    var interpreter = BindingInterpreter(binding: .chord([.control, .option]))

    // When: Control alone, then Option completes the chord
    let partial = interpreter.interpret(
        .flagsChanged(keyCode: Key.control, modifiers: [.control], fnDown: false))
    let complete = interpreter.interpret(
        .flagsChanged(keyCode: Key.option, modifiers: [.control, .option], fnDown: false))

    // Then
    #expect(partial == .otherKey)
    #expect(complete == .hotkeyChanged(isDown: true))
}

@Test func givenAHeldChordWhenAModifierLeavesThenTheHotkeyGoesUpOnce() {
    // Given
    var interpreter = BindingInterpreter(binding: .chord([.control, .option]))
    _ = interpreter.interpret(
        .flagsChanged(keyCode: Key.option, modifiers: [.control, .option], fnDown: false))

    // When: Option releases, then Control — only the break is a transition
    let broken = interpreter.interpret(
        .flagsChanged(keyCode: Key.option, modifiers: [.control], fnDown: false))
    let last = interpreter.interpret(
        .flagsChanged(keyCode: Key.control, modifiers: [], fnDown: false))

    // Then
    #expect(broken == .hotkeyChanged(isDown: false))
    #expect(last == .otherKey)
}

@Test func givenAHeldChordWhenAnExtraModifierJoinsThenTheHoldContinuesSilently() {
    // Given
    var interpreter = BindingInterpreter(binding: .chord([.control, .option]))
    _ = interpreter.interpret(
        .flagsChanged(keyCode: Key.option, modifiers: [.control, .option], fnDown: false))

    // When
    let event = interpreter.interpret(
        .flagsChanged(keyCode: Key.shift, modifiers: [.control, .option, .shift], fnDown: false))

    // Then
    #expect(event == .otherKey)
}

@Test func givenAChordBindingWhenFnOrPlainKeysArriveThenTheyPassAsOtherKeys() {
    // Given
    var interpreter = BindingInterpreter(binding: .chord([.control, .option]))

    // When
    let fn = interpreter.interpret(.flagsChanged(keyCode: Key.fn, modifiers: [], fnDown: true))
    let key = interpreter.interpret(.keyDown(keyCode: Key.letter))

    // Then
    #expect(fn == .otherKey)
    #expect(key == .otherKey)
}

@Test func givenAHeldChordWhenTheTapIsDisabledThenTheHoldStateResets() {
    // Given
    var interpreter = BindingInterpreter(binding: .chord([.control, .option]))
    _ = interpreter.interpret(
        .flagsChanged(keyCode: Key.option, modifiers: [.control, .option], fnDown: false))

    // When
    let disabled = interpreter.interpret(.tapDisabled)
    let reheld = interpreter.interpret(
        .flagsChanged(keyCode: Key.option, modifiers: [.control, .option], fnDown: false))

    // Then: a fresh chord press after re-enable is a fresh down
    #expect(disabled == .tapDisabled)
    #expect(reheld == .hotkeyChanged(isDown: true))
}

@Test func givenAHeldChordWhenRebindingThenTheNewBindingStartsFromIdle() {
    // Given
    var interpreter = BindingInterpreter(binding: .chord([.control]))
    _ = interpreter.interpret(
        .flagsChanged(keyCode: Key.control, modifiers: [.control], fnDown: false))

    // When
    interpreter.rebind(to: .chord([.command]))
    let event = interpreter.interpret(
        .flagsChanged(keyCode: Key.control, modifiers: [], fnDown: false))

    // Then: the old chord's release is not a transition of the new binding
    #expect(event == .otherKey)
}
