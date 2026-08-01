import AppKit
import Testing

@testable import CalamoInsertion

@Test func givenACopiedTextWhenADictationIsPastedThenTheClipboardIsRestoredAfterTheDelay()
    async throws
{
    // Given: the user's real clipboard, put back once the test is done
    let pasteboard = NSPasteboard.general
    let before = PasteboardSnapshot.capture(from: pasteboard)
    defer { onMainSync { before.restore(to: pasteboard) } }
    onMainSync {
        pasteboard.clearContents()
        pasteboard.setString("previously copied", forType: .string)
    }
    let insertion = SimulatedPasteInsertion(
        pasteboard: pasteboard, restoreDelay: 0.05, paste: { true })

    // When
    let pasted = onMainSync {
        insertion.attempt("Première ligne — déjà vu, garçon, cœur.\nDeuxième ligne.")
    }
    try await Task.sleep(for: .milliseconds(500))

    // Then
    #expect(pasted)
    #expect(pasteboard.string(forType: .string) == "previously copied")
}

@Test func givenADictationWhenThePasteFiresThenThePasteboardContentIsMarkedTransientAndConcealed()
    throws
{
    // Given
    let pasteboard = scratchPasteboard()
    defer { pasteboard.releaseGlobally() }
    var typesAtPaste: [NSPasteboard.PasteboardType] = []
    var textAtPaste: String?
    let insertion = SimulatedPasteInsertion(
        pasteboard: pasteboard, restoreDelay: 0.05,
        paste: {
            typesAtPaste = pasteboard.pasteboardItems?.first?.types ?? []
            textAtPaste = pasteboard.string(forType: .string)
            return true
        })

    // When
    _ = onMainSync { insertion.attempt("dictated") }

    // Then
    #expect(textAtPaste == "dictated")
    #expect(typesAtPaste.contains(NSPasteboard.PasteboardType("org.nspasteboard.TransientType")))
    #expect(typesAtPaste.contains(NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")))
}

@Test func givenAFailedPasteWhenAFallbackInsertedTheTextThenTheUsersCopyComesBack() throws {
    // Given
    let pasteboard = scratchPasteboard()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    pasteboard.setString("previously copied", forType: .string)
    let insertion = SimulatedPasteInsertion(
        pasteboard: pasteboard, restoreDelay: 0.05, paste: { false })

    // When: the paste fails, then the cascade reports a fallback success
    let pasted = onMainSync { insertion.attempt("dictated") }
    onMainSync { insertion.restoreAbandonedSnapshot() }

    // Then
    #expect(!pasted)
    #expect(pasteboard.string(forType: .string) == "previously copied")
}

@Test func givenAFailedPasteWhenTheCascadeLeavesTheTextThenItStaysWithoutTransientMarks() throws {
    // Given
    let pasteboard = scratchPasteboard()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    pasteboard.setString("previously copied", forType: .string)
    let insertion = SimulatedPasteInsertion(
        pasteboard: pasteboard, restoreDelay: 0.05, paste: { false })

    // When
    _ = onMainSync { insertion.attempt("dictated") }
    onMainSync { insertion.leaveTextForManualPaste("dictated") }

    // Then: recoverable by hand with Cmd-V, visible to clipboard managers
    #expect(pasteboard.string(forType: .string) == "dictated")
    let types = pasteboard.pasteboardItems?.first?.types ?? []
    #expect(!types.contains(NSPasteboard.PasteboardType("org.nspasteboard.TransientType")))
    #expect(!types.contains(NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")))
}

@Test func givenAUserCopyDuringTheRestoreWindowWhenTheRestoreFiresThenTheUsersCopyIsPreserved()
    async throws
{
    // Given
    let pasteboard = scratchPasteboard()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    pasteboard.setString("previously copied", forType: .string)
    let insertion = SimulatedPasteInsertion(
        pasteboard: pasteboard, restoreDelay: 0.2, paste: { true })

    // When: the user copies before the deferred restore fires
    _ = onMainSync { insertion.attempt("dictated") }
    onMainSync {
        pasteboard.clearContents()
        pasteboard.setString("user copy", forType: .string)
    }
    try await Task.sleep(for: .milliseconds(700))

    // Then
    #expect(pasteboard.string(forType: .string) == "user copy")
}

@Test func givenBackToBackDictationsWhenTheSecondArrivesBeforeTheRestoreThenTheOriginalClipboardIsRestored()
    async throws
{
    // Given
    let pasteboard = scratchPasteboard()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    pasteboard.setString("previously copied", forType: .string)
    let insertion = SimulatedPasteInsertion(
        pasteboard: pasteboard, restoreDelay: 0.2, paste: { true })

    // When
    _ = onMainSync { insertion.attempt("first dictation") }
    _ = onMainSync { insertion.attempt("second dictation") }
    try await Task.sleep(for: .milliseconds(700))

    // Then: not "first dictation" — the held snapshot carried over
    #expect(pasteboard.string(forType: .string) == "previously copied")
}

func scratchPasteboard() -> NSPasteboard {
    NSPasteboard(name: NSPasteboard.Name("dev.calamo.tests.\(UUID().uuidString)"))
}
