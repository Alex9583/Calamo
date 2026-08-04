import CalamoInput
import Testing

@Test func givenAGrantedProcessWhenTheTapIsMissingThenTheVerdictIsRecreate() {
    // Given
    let trusted = true

    // When
    let verdict = TapGuard.reconcile(trusted: trusted, tapActive: false)

    // Then
    #expect(verdict == .recreate)
}

@Test func givenAGrantedProcessWhenTheTapIsActiveThenTheVerdictIsKeep() {
    // Given
    let trusted = true

    // When
    let verdict = TapGuard.reconcile(trusted: trusted, tapActive: true)

    // Then
    #expect(verdict == .keep)
}

@Test func givenARevokedGrantWhenTheTapIsStillActiveThenTheVerdictIsTearDown() {
    // Given: revocation never killed the tap by itself
    let trusted = false

    // When
    let verdict = TapGuard.reconcile(trusted: trusted, tapActive: true)

    // Then
    #expect(verdict == .tearDown)
}

@Test func givenARevokedGrantWhenTheTapIsAlreadyGoneThenTheVerdictIsKeep() {
    // Given
    let trusted = false

    // When
    let verdict = TapGuard.reconcile(trusted: trusted, tapActive: false)

    // Then
    #expect(verdict == .keep)
}
