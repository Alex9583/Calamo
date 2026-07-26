import Testing

@testable import CalamoInsertion

@Test func givenTheActiveKeyboardLayoutWhenResolvingThePasteKeyThenTheKeycodeTranslatesBackToV()
    async throws
{
    // Given: the active layout, read on the main thread as TIS requires
    let resolved = await MainActor.run { PasteKeycode.resolveV() }
    guard let resolved else {
        // No layout translation data (headless session) — production falls
        // back to kVK_ANSI_V, nothing to verify here.
        return
    }

    // When
    let character = await MainActor.run { PasteKeycode.character(for: resolved) }

    // Then
    #expect(character == "v")
}
