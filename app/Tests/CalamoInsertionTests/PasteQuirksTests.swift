import Testing

@testable import CalamoInsertion

@Test func givenNoEnvironmentOverrideWhenDerivingQuirksThenTheStandardListApplies() {
    // Given
    let env: [String: String] = [:]

    // When
    let quirks = PasteQuirks.fromEnvironment(env)

    // Then
    #expect(quirks.pasteBlockedBundleIDs == PasteQuirks.standard.pasteBlockedBundleIDs)
}

@Test func givenABlockedListInTheEnvironmentWhenDerivingQuirksThenThoseAppsBlockPaste() {
    // Given
    let env = ["CALAMO_PASTE_BLOCKED": "com.apple.TextEdit,com.tinyspeck.slackmacgap"]

    // When
    let quirks = PasteQuirks.fromEnvironment(env)

    // Then
    #expect(quirks.blocksPaste(bundleID: "com.apple.TextEdit"))
    #expect(quirks.blocksPaste(bundleID: "com.tinyspeck.slackmacgap"))
    #expect(!quirks.blocksPaste(bundleID: "com.apple.Safari"))
}
