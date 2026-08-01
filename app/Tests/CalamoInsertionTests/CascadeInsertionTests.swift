import AppKit
import CalamoCore
import Testing

@testable import CalamoInsertion

@Test func givenASecureFieldWhenInsertingThenTheRefusalComesBeforeAnythingIsTouched() throws {
    // Given
    let pasteboard = scratchPasteboard()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    pasteboard.setString("previously copied", forType: .string)
    var pasted = false
    var typed = false
    let insertion = CascadeInsertion(
        environment: { environment(secureField: true) },
        paste: SimulatedPasteInsertion(
            pasteboard: pasteboard, restoreDelay: 0.05,
            paste: {
                pasted = true
                return true
            }),
        typeSegments: { _ in
            typed = true
            return true
        },
        quirks: .standard)

    // When
    let caught = insertionError(from: insertion, text: "dictated")

    // Then
    #expect(caught == .SecureField)
    #expect(!pasted)
    #expect(!typed)
    #expect(pasteboard.string(forType: .string) == "previously copied")
}

@Test func givenAnOrdinaryAppWhenThePasteSucceedsThenNoKeystrokeIsEverTyped() throws {
    // Given
    let pasteboard = scratchPasteboard()
    defer { pasteboard.releaseGlobally() }
    var typed = false
    let insertion = CascadeInsertion(
        environment: { environment() },
        paste: SimulatedPasteInsertion(
            pasteboard: pasteboard, restoreDelay: 0.05, paste: { true }),
        typeSegments: { _ in
            typed = true
            return true
        },
        quirks: .standard)

    // When
    try insertion.insert(text: "dictated")

    // Then
    #expect(!typed)
}

@Test func givenAFailedPasteWhenTheKeystrokeFallbackSucceedsThenTheUsersCopyIsRestored() throws {
    // Given
    let pasteboard = scratchPasteboard()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    pasteboard.setString("previously copied", forType: .string)
    var typedSegments: [KeystrokeSegment] = []
    let insertion = CascadeInsertion(
        environment: { environment() },
        paste: SimulatedPasteInsertion(
            pasteboard: pasteboard, restoreDelay: 0.05, paste: { false }),
        typeSegments: { segments in
            typedSegments = segments
            return true
        },
        quirks: .standard)

    // When
    try insertion.insert(text: "ligne un\nligne deux")

    // Then: the text went out as keystrokes, the clipboard is untouched
    #expect(typedSegments == [.text("ligne un"), .key(.newline), .text("ligne deux")])
    #expect(pasteboard.string(forType: .string) == "previously copied")
}

@Test func givenEveryStepFailingWhenInsertingThenTheTextIsLeftOnThePasteboardAndTheFailureRaised()
    throws
{
    // Given
    let pasteboard = scratchPasteboard()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    pasteboard.setString("previously copied", forType: .string)
    let insertion = CascadeInsertion(
        environment: { environment() },
        paste: SimulatedPasteInsertion(
            pasteboard: pasteboard, restoreDelay: 0.05, paste: { false }),
        typeSegments: { _ in false },
        quirks: .standard)

    // When
    let caught = insertionError(from: insertion, text: "dictated")

    // Then: the failure is raised but the dictation is never lost
    #expect(caught != nil)
    #expect(pasteboard.string(forType: .string) == "dictated")
}

@Test func givenAnAppKnownToBlockPasteWhenInsertingThenKeystrokesGoOutWithoutTouchingTheClipboard()
    throws
{
    // Given
    let pasteboard = scratchPasteboard()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    pasteboard.setString("previously copied", forType: .string)
    var pasted = false
    var typed = false
    let insertion = CascadeInsertion(
        environment: { environment(app: "com.example.emm") },
        paste: SimulatedPasteInsertion(
            pasteboard: pasteboard, restoreDelay: 0.05,
            paste: {
                pasted = true
                return true
            }),
        typeSegments: { _ in
            typed = true
            return true
        },
        quirks: PasteQuirks(pasteBlockedBundleIDs: ["com.example.emm"]))

    // When
    try insertion.insert(text: "dictated")

    // Then
    #expect(!pasted)
    #expect(typed)
    #expect(pasteboard.string(forType: .string) == "previously copied")
}

@Test func givenABlockedAppWhoseKeystrokesFailWhenInsertingThenTheTextStillLandsOnThePasteboard()
    throws
{
    // Given
    let pasteboard = scratchPasteboard()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    pasteboard.setString("previously copied", forType: .string)
    let insertion = CascadeInsertion(
        environment: { environment(app: "com.example.emm") },
        paste: SimulatedPasteInsertion(
            pasteboard: pasteboard, restoreDelay: 0.05, paste: { true }),
        typeSegments: { _ in false },
        quirks: PasteQuirks(pasteBlockedBundleIDs: ["com.example.emm"]))

    // When
    let caught = insertionError(from: insertion, text: "dictated")

    // Then
    #expect(caught != nil)
    #expect(pasteboard.string(forType: .string) == "dictated")
}

@Test func givenACallFromThePipelineThreadWhenInsertingThenProbesAndPasteRunOnTheMainQueue()
    async throws
{
    // Given
    let pasteboard = scratchPasteboard()
    defer { pasteboard.releaseGlobally() }
    var probeWasOnMain = false
    var pasteWasOnMain = false
    let insertion = CascadeInsertion(
        environment: {
            probeWasOnMain = Thread.isMainThread
            return environment()
        },
        paste: SimulatedPasteInsertion(
            pasteboard: pasteboard, restoreDelay: 0.05,
            paste: {
                pasteWasOnMain = Thread.isMainThread
                return true
            }),
        typeSegments: { _ in true },
        quirks: .standard)

    // When
    await insertFromPipelineThread(insertion, text: "dictated")

    // Then
    #expect(probeWasOnMain)
    #expect(pasteWasOnMain)
}

private func insertionError(from insertion: CascadeInsertion, text: String) -> InsertionError? {
    do {
        try insertion.insert(text: text)
        return nil
    } catch {
        return error as? InsertionError
    }
}

/// Calls insert from a plain thread, as the engine's pipeline thread does.
private func insertFromPipelineThread(_ insertion: CascadeInsertion, text: String) async {
    let done = DispatchSemaphore(value: 0)
    Thread.detachNewThread {
        try? insertion.insert(text: text)
        done.signal()
    }
    await withCheckedContinuation { continuation in
        DispatchQueue.global().async {
            done.wait()
            continuation.resume()
        }
    }
}

private func environment(
    secureField: Bool = false, secureInput: Bool = false, app: String? = "com.apple.TextEdit"
) -> InsertionEnvironment {
    InsertionEnvironment(
        fieldIsSecure: secureField, secureInputActive: secureInput, frontAppBundleID: app)
}
