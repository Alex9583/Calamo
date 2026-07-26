import AppKit
import CalamoCore
import Testing

@testable import CalamoInsertion

@Test func givenACopiedTextWhenADictationIsInsertedThenTheClipboardIsRestoredAfterTheDelay()
    async throws
{
    // Given: the user's real clipboard, put back once the test is done
    let pasteboard = NSPasteboard.general
    let before = PasteboardSnapshot.capture(from: pasteboard)
    defer { before.restore(to: pasteboard) }
    pasteboard.clearContents()
    pasteboard.setString("previously copied", forType: .string)
    let insertion = SimulatedPasteInsertion(
        pasteboard: pasteboard, restoreDelay: 0.05, paste: { true })

    // When
    try insertion.insert(text: "Première ligne — déjà vu, garçon, cœur.\nDeuxième ligne.")
    try await Task.sleep(for: .milliseconds(500))

    // Then
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
    try insertion.insert(text: "dictated")

    // Then
    #expect(textAtPaste == "dictated")
    #expect(typesAtPaste.contains(NSPasteboard.PasteboardType("org.nspasteboard.TransientType")))
    #expect(typesAtPaste.contains(NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")))
}

@Test func givenAPasteThatCannotBePostedWhenInsertingThenTheDictationStaysOnThePasteboard()
    async throws
{
    // Given
    let pasteboard = scratchPasteboard()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    pasteboard.setString("previously copied", forType: .string)
    let insertion = SimulatedPasteInsertion(
        pasteboard: pasteboard, restoreDelay: 0.05, paste: { false })

    // When
    #expect(throws: InsertionError.self) {
        try insertion.insert(text: "dictated")
    }
    try await Task.sleep(for: .milliseconds(300))

    // Then: recoverable by hand with Cmd-V — restoring would erase it
    #expect(pasteboard.string(forType: .string) == "dictated")
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
    try insertion.insert(text: "dictated")
    pasteboard.clearContents()
    pasteboard.setString("user copy", forType: .string)
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
    try insertion.insert(text: "first dictation")
    try insertion.insert(text: "second dictation")
    try await Task.sleep(for: .milliseconds(700))

    // Then: not "first dictation" — the held snapshot carried over
    #expect(pasteboard.string(forType: .string) == "previously copied")
}

@Test func givenACallFromThePipelineThreadWhenInsertingThenPasteboardWorkRunsOnTheMainQueue()
    async throws
{
    // Given
    let pasteboard = scratchPasteboard()
    defer { pasteboard.releaseGlobally() }
    var pasteWasOnMain = false
    let insertion = SimulatedPasteInsertion(
        pasteboard: pasteboard, restoreDelay: 0.05,
        paste: {
            pasteWasOnMain = Thread.isMainThread
            return true
        })

    // When: called from a plain thread, as the engine's pipeline thread does
    let done = DispatchSemaphore(value: 0)
    Thread.detachNewThread {
        try? insertion.insert(text: "dictated")
        done.signal()
    }
    await withCheckedContinuation { continuation in
        DispatchQueue.global().async {
            done.wait()
            continuation.resume()
        }
    }

    // Then
    #expect(pasteWasOnMain)
}

private func scratchPasteboard() -> NSPasteboard {
    NSPasteboard(name: NSPasteboard.Name("dev.calamo.tests.\(UUID().uuidString)"))
}
