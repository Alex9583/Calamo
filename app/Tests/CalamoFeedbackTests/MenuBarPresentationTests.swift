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

@Test func givenADownloadInFlightWhenTheEngineIsLoadingThenTheLineCountsReadyModels() {
    // Given
    let snapshot = MenuBarSnapshot(
        engine: .loading, accessibilityGranted: true, microphoneGranted: true,
        secureInputActive: false, hotkeyLabel: "Fn",
        download: ModelDownloadProgress(ready: 1, total: 3))

    // When
    let presentation = MenuBarPresentation.derive(from: snapshot)

    // Then
    #expect(
        presentation
            == MenuBarPresentation(
                icon: .loading, status: StatusLine(label: "Loading models… (1/3)")))
}

@Test func givenAStaleDownloadCountWhenTheEngineIsReadyThenTheLineIgnoresIt() {
    // Given: a progress report that outlived its download
    let snapshot = MenuBarSnapshot(
        engine: .ready, accessibilityGranted: true, microphoneGranted: true,
        secureInputActive: false, hotkeyLabel: "Fn",
        download: ModelDownloadProgress(ready: 3, total: 3))

    // When
    let presentation = MenuBarPresentation.derive(from: snapshot)

    // Then
    #expect(presentation.status == StatusLine(label: "Ready — hold Fn to dictate"))
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

@Test func givenAPostUpdateColdStartWhenTheEngineIsLoadingThenTheLineExplainsTheOptimization() {
    // Given: the binary changed — the ANE caches recompile
    let snapshot = MenuBarSnapshot(
        engine: .loading, accessibilityGranted: true, microphoneGranted: true,
        secureInputActive: false, hotkeyLabel: "Fn", coldStart: .postUpdate)

    // When
    let presentation = MenuBarPresentation.derive(from: snapshot)

    // Then
    #expect(
        presentation
            == MenuBarPresentation(
                icon: .loading,
                status: StatusLine(label: "Optimizing after update… (~1 min, once)")))
}

@Test func givenAPostUpdateColdStartWhenADownloadIsInFlightThenTheDownloadCountWins() {
    // Given: an update that also ships new model files
    let snapshot = MenuBarSnapshot(
        engine: .loading, accessibilityGranted: true, microphoneGranted: true,
        secureInputActive: false, hotkeyLabel: "Fn",
        download: ModelDownloadProgress(ready: 2, total: 3), coldStart: .postUpdate)

    // When
    let presentation = MenuBarPresentation.derive(from: snapshot)

    // Then
    #expect(presentation.status == StatusLine(label: "Loading models… (2/3)"))
}

@Test func givenAPostUpdateColdStartWhenTheEngineIsReadyThenTheLineInvitesDictation() {
    // Given
    let snapshot = MenuBarSnapshot(
        engine: .ready, accessibilityGranted: true, microphoneGranted: true,
        secureInputActive: false, hotkeyLabel: "Fn", coldStart: .postUpdate)

    // When
    let presentation = MenuBarPresentation.derive(from: snapshot)

    // Then
    #expect(presentation.status == StatusLine(label: "Ready — hold Fn to dictate"))
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
