// Pins the persistent state → icon/status-line mapping the status item
// renders verbatim.
import CalamoCore
import CalamoFeedback
import Testing

@Test func givenAllGrantedWhenTheEngineIsReadyThenTheIconIsFullAndTheLineInvitesDictation() {
    // Given
    let snapshot = MenuBarSnapshot(
        engine: .ready, accessibilityGranted: true, microphoneGranted: true,
        secureInputActive: false, hotkeyLabel: "Fn")

    // When
    let presentation = MenuBarPresentation.derive(from: snapshot)

    // Then
    #expect(
        presentation
            == MenuBarPresentation(
                icon: .ready, status: StatusLine(label: "Ready — hold Fn to dictate")))
}

@Test func givenAReboundChordWhenTheEngineIsReadyThenTheLineInvitesWithTheChord() {
    // Given
    let snapshot = MenuBarSnapshot(
        engine: .ready, accessibilityGranted: true, microphoneGranted: true,
        secureInputActive: false, hotkeyLabel: "⌃⌥")

    // When
    let presentation = MenuBarPresentation.derive(from: snapshot)

    // Then
    #expect(presentation.status == StatusLine(label: "Ready — hold ⌃⌥ to dictate"))
}

@Test func givenAllGrantedWhenTheEngineIsLoadingThenTheIconPulsesAndTheLineSaysLoading() {
    // Given
    let snapshot = MenuBarSnapshot(
        engine: .loading, accessibilityGranted: true, microphoneGranted: true,
        secureInputActive: false, hotkeyLabel: "Fn")

    // When
    let presentation = MenuBarPresentation.derive(from: snapshot)

    // Then
    #expect(
        presentation
            == MenuBarPresentation(icon: .loading, status: StatusLine(label: "Loading models…")))
}

@Test func givenAllGrantedWhenModelsAreMissingThenTheWarningShowsAndTheLineOffersRedownload() {
    // Given
    let snapshot = MenuBarSnapshot(
        engine: .unavailable(cause: .modelsMissing), accessibilityGranted: true,
        microphoneGranted: true, secureInputActive: false, hotkeyLabel: "Fn")

    // When
    let presentation = MenuBarPresentation.derive(from: snapshot)

    // Then
    #expect(
        presentation
            == MenuBarPresentation(
                icon: .unavailable,
                status: StatusLine(label: "Models missing — Redownload", action: .redownloadModels)
            ))
}

@Test func givenAReadyEngineWhenSecureInputIsActiveThenThePadlockShowsWithoutAction() {
    // Given
    let snapshot = MenuBarSnapshot(
        engine: .ready, accessibilityGranted: true, microphoneGranted: true,
        secureInputActive: true, hotkeyLabel: "Fn")

    // When
    let presentation = MenuBarPresentation.derive(from: snapshot)

    // Then
    #expect(
        presentation
            == MenuBarPresentation(
                icon: .secureInput,
                status: StatusLine(label: "Secure input active — dictation muted")))
}

@Test func givenAReadyEngineWhenAccessibilityIsRevokedThenTheLineGuidesToSystemSettings() {
    // Given
    let snapshot = MenuBarSnapshot(
        engine: .ready, accessibilityGranted: false, microphoneGranted: true,
        secureInputActive: false, hotkeyLabel: "Fn")

    // When
    let presentation = MenuBarPresentation.derive(from: snapshot)

    // Then
    #expect(
        presentation
            == MenuBarPresentation(
                icon: .unavailable,
                status: StatusLine(
                    label: "Accessibility permission needed — Open System Settings",
                    action: .openAccessibilitySettings)))
}

@Test func givenModelsMissingWhenAccessibilityIsAlsoRevokedThenThePermissionLineWins() {
    // Given
    let snapshot = MenuBarSnapshot(
        engine: .unavailable(cause: .modelsMissing), accessibilityGranted: false,
        microphoneGranted: true, secureInputActive: false, hotkeyLabel: "Fn")

    // When
    let presentation = MenuBarPresentation.derive(from: snapshot)

    // Then
    #expect(presentation.status.action == .openAccessibilitySettings)
}

@Test func givenAReadyEngineWhenMicrophoneIsDeniedThenTheLineGuidesToSystemSettings() {
    // Given
    let snapshot = MenuBarSnapshot(
        engine: .ready, accessibilityGranted: true, microphoneGranted: false,
        secureInputActive: false, hotkeyLabel: "Fn")

    // When
    let presentation = MenuBarPresentation.derive(from: snapshot)

    // Then
    #expect(
        presentation
            == MenuBarPresentation(
                icon: .unavailable,
                status: StatusLine(
                    label: "Microphone permission needed — Open System Settings",
                    action: .openMicrophoneSettings)))
}

@Test func givenBothPermissionsRevokedWhenDerivingThenAccessibilityGuidesFirst() {
    // Given
    let snapshot = MenuBarSnapshot(
        engine: .ready, accessibilityGranted: false, microphoneGranted: false,
        secureInputActive: false, hotkeyLabel: "Fn")

    // When
    let presentation = MenuBarPresentation.derive(from: snapshot)

    // Then
    #expect(presentation.status.action == .openAccessibilitySettings)
}

@Test func givenALoadingEngineWhenSecureInputIsActiveThenLoadingStillShows() {
    // Given
    let snapshot = MenuBarSnapshot(
        engine: .loading, accessibilityGranted: true, microphoneGranted: true,
        secureInputActive: true, hotkeyLabel: "Fn")

    // When
    let presentation = MenuBarPresentation.derive(from: snapshot)

    // Then
    #expect(
        presentation
            == MenuBarPresentation(icon: .loading, status: StatusLine(label: "Loading models…")))
}
