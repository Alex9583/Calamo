import Testing

@testable import CalamoInsertion

@Test func givenAShortPlainTextWhenSegmentedThenItIsASingleChunk() {
    // Given
    let text = "bonjour le monde"

    // When
    let segments = KeystrokeSegments.segments(of: text)

    // Then
    #expect(segments == [.text("bonjour le monde")])
}

@Test func givenALongTextWhenSegmentedThenChunksStayUnderTwentyUnitsAndRebuildTheText() {
    // Given
    let text = String(repeating: "déjà vu, garçon — ", count: 6)

    // When
    let segments = KeystrokeSegments.segments(of: text)

    // Then
    let chunks = segments.compactMap { if case .text(let chunk) = $0 { chunk } else { nil } }
    #expect(chunks.joined() == text)
    #expect(chunks.allSatisfy { $0.utf16.count <= 20 })
    #expect(segments.count == chunks.count)
}

@Test func givenAMultilineTextWhenSegmentedThenNewlinesBecomeKeyPressesBetweenChunks() {
    // Given
    let text = "première ligne\nseconde"

    // When
    let segments = KeystrokeSegments.segments(of: text)

    // Then
    #expect(segments == [.text("première ligne"), .key(.newline), .text("seconde")])
}

@Test func givenAWindowsNewlineWhenSegmentedThenItCollapsesToASingleReturnPress() {
    // Given
    let text = "a\r\nb"

    // When
    let segments = KeystrokeSegments.segments(of: text)

    // Then
    #expect(segments == [.text("a"), .key(.newline), .text("b")])
}

@Test func givenALeadingNewlineWhenSegmentedThenNoTextChunkStartsWithAControlCharacter() {
    // Given: a chunk starting with a control character is silently dropped
    // by CGEventKeyboardSetUnicodeString (enigo #260)
    let text = "\ndeuxième"

    // When
    let segments = KeystrokeSegments.segments(of: text)

    // Then
    #expect(segments == [.key(.newline), .text("deuxième")])
}

@Test func givenATabWhenSegmentedThenItBecomesATabKeyPress() {
    // Given
    let text = "a\tb"

    // When
    let segments = KeystrokeSegments.segments(of: text)

    // Then
    #expect(segments == [.text("a"), .key(.tab), .text("b")])
}

@Test func givenFlagEmojiWhenSegmentedThenChunkBoundariesNeverSplitAGrapheme() {
    // Given: each flag is 4 UTF-16 units, so 20 does not divide the run evenly
    let text = String(repeating: "🇫🇷", count: 11)

    // When
    let segments = KeystrokeSegments.segments(of: text)

    // Then
    let chunks = segments.compactMap { if case .text(let chunk) = $0 { chunk } else { nil } }
    #expect(chunks.joined() == text)
    #expect(chunks.allSatisfy { $0.utf16.count <= 20 })
}

@Test func givenAnEmptyTextWhenSegmentedThenThereIsNothingToType() {
    // Given
    let text = ""

    // When
    let segments = KeystrokeSegments.segments(of: text)

    // Then
    #expect(segments == [])
}
