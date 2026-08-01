import CalamoInput
import Testing

@Test func givenTheFnBindingWhenRenderingItsLabelThenItReadsFn() {
    // Given
    let binding = HotkeyBinding.fn

    // When
    let label = binding.label

    // Then
    #expect(label == "Fn")
}

@Test func givenAChordWhenRenderingItsLabelThenModifiersFollowTheSystemOrder() {
    // Given: recorded in any order, displayed ⌃⌥⇧⌘
    let binding = HotkeyBinding.chord([.command, .control, .option, .shift])

    // When
    let label = binding.label

    // Then
    #expect(label == "⌃⌥⇧⌘")
}

@Test func givenAnyBindingWhenRoundTrippingThroughRawValueThenItSurvives() {
    // Given
    let bindings: [HotkeyBinding] = [.fn, .chord([.control, .option]), .chord([.command])]

    // When
    let revived = bindings.map { HotkeyBinding(rawValue: $0.rawValue) }

    // Then
    #expect(revived == bindings)
}

@Test func givenAForeignRawValueWhenParsingThenTheBindingIsRejected() {
    // Given: a defaults value written by no released Calamo
    let foreign = ["", "fn+control", "hyper", "control+"]

    // When
    let parsed = foreign.map(HotkeyBinding.init(rawValue:))

    // Then
    #expect(parsed.allSatisfy { $0 == nil })
}

@Test func givenTheFnBindingWhenANonAppleExternalKeyboardIsPresentThenCtrlOptionIsProposed() {
    // Given
    let current = HotkeyBinding.fn

    // When
    let proposal = HotkeyBinding.proposal(current: current, hasNonAppleExternalKeyboard: true)

    // Then
    #expect(proposal == .chord([.control, .option]))
}

@Test func givenARebindOrAnAppleOnlySetupWhenDerivingTheProposalThenNoneIsMade() {
    // Given: already rebound, or no external non-Apple keyboard
    let rebound = HotkeyBinding.chord([.command])

    // When
    let afterRebind = HotkeyBinding.proposal(current: rebound, hasNonAppleExternalKeyboard: true)
    let appleOnly = HotkeyBinding.proposal(current: .fn, hasNonAppleExternalKeyboard: false)

    // Then
    #expect(afterRebind == nil)
    #expect(appleOnly == nil)
}

@Test func givenEachBindingKindWhenAskingWhoSwallowsTapEventsThenOnlyFnDoes() {
    // Given
    let fn = HotkeyBinding.fn
    let chord = HotkeyBinding.chord([.control, .option])

    // When
    let fnSwallows = fn.swallowsEvents
    let chordSwallows = chord.swallowsEvents

    // Then: Fn swallowed suppresses globe actions; bare modifiers trigger
    // nothing, and swallowing them would desync frontmost apps
    #expect(fnSwallows)
    #expect(!chordSwallows)
}
