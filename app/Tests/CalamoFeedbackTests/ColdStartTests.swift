// Pins the identity comparison that decides the post-update label.
import CalamoFeedback
import Testing

@Test func givenNoRecordedIdentityWhenClassifyingThenTheColdStartIsOrdinary() {
    // Given: a first install — nothing compiled yet
    let recorded: String? = nil

    // When
    let coldStart = ColdStart.classify(current: "AAA", lastCompiled: recorded)

    // Then
    #expect(coldStart == .ordinary)
}

@Test func givenAMatchingIdentityWhenClassifyingThenTheColdStartIsOrdinary() {
    // When
    let coldStart = ColdStart.classify(current: "AAA", lastCompiled: "AAA")

    // Then
    #expect(coldStart == .ordinary)
}

@Test func givenAChangedIdentityWhenClassifyingThenTheColdStartIsPostUpdate() {
    // Given: the binary was updated since the last successful load
    let lastCompiled = "AAA"

    // When
    let coldStart = ColdStart.classify(current: "BBB", lastCompiled: lastCompiled)

    // Then
    #expect(coldStart == .postUpdate)
}

@Test func givenAnUnreadableCurrentIdentityWhenClassifyingThenTheColdStartIsOrdinary() {
    // When
    let coldStart = ColdStart.classify(current: nil, lastCompiled: "AAA")

    // Then
    #expect(coldStart == .ordinary)
}
