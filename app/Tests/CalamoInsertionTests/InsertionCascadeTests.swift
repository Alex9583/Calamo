import Testing

@testable import CalamoInsertion

@Test func givenASecureFocusedFieldWhenPlanningThenTheDictationIsRefused() {
    // Given
    let environment = InsertionEnvironment(
        fieldIsSecure: true, secureInputActive: false, frontAppBundleID: "com.apple.Safari")

    // When
    let plan = InsertionCascade.plan(environment, quirks: .standard)

    // Then
    #expect(plan == .refuseSecureField)
}

@Test func givenActiveSecureInputWhenPlanningThenTheDictationIsRefused() {
    // Given: no secure subrole seen, but some process holds secure input
    let environment = InsertionEnvironment(
        fieldIsSecure: false, secureInputActive: true, frontAppBundleID: "com.apple.Safari")

    // When
    let plan = InsertionCascade.plan(environment, quirks: .standard)

    // Then
    #expect(plan == .refuseSecureField)
}

@Test func givenAnOrdinaryAppWhenPlanningThenPasteComesFirstAndKeystrokesBackItUp() {
    // Given
    let environment = InsertionEnvironment(
        fieldIsSecure: false, secureInputActive: false, frontAppBundleID: "com.apple.TextEdit")

    // When
    let plan = InsertionCascade.plan(environment, quirks: .standard)

    // Then
    #expect(plan == .attempt([.simulatedPaste, .simulatedKeystrokes]))
}

@Test func givenAnAppKnownToBlockPasteWhenPlanningThenKeystrokesAreTargetedDirectly() {
    // Given
    let quirks = PasteQuirks(pasteBlockedBundleIDs: ["com.citrix.receiver.icaviewer.mac"])
    let environment = InsertionEnvironment(
        fieldIsSecure: false, secureInputActive: false,
        frontAppBundleID: "com.citrix.receiver.icaviewer.mac")

    // When
    let plan = InsertionCascade.plan(environment, quirks: quirks)

    // Then
    #expect(plan == .attempt([.simulatedKeystrokes]))
}

@Test func givenAnUnidentifiedFrontAppWhenPlanningThenTheOrdinaryCascadeApplies() {
    // Given
    let quirks = PasteQuirks(pasteBlockedBundleIDs: ["com.citrix.receiver.icaviewer.mac"])
    let environment = InsertionEnvironment(
        fieldIsSecure: false, secureInputActive: false, frontAppBundleID: nil)

    // When
    let plan = InsertionCascade.plan(environment, quirks: quirks)

    // Then
    #expect(plan == .attempt([.simulatedPaste, .simulatedKeystrokes]))
}
