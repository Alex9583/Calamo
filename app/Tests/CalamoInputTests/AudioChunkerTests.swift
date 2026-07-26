import CalamoInput
import Testing

@Test func givenFewerSamplesThanAChunkWhenAppendedThenNoChunkIsEmitted() {
    // Given
    var chunker = AudioChunker(chunkSize: 4)

    // When
    let chunks = chunker.append([1, 2, 3])

    // Then
    #expect(chunks.isEmpty)
}

@Test func givenAPartialChunkPendingWhenMoreSamplesArriveThenTheChunkCrossesTheBufferBoundary() {
    // Given
    var chunker = AudioChunker(chunkSize: 4)

    // When
    let first = chunker.append([1, 2, 3])
    let second = chunker.append([4, 5])

    // Then
    #expect(first.isEmpty)
    #expect(second == [[1, 2, 3, 4]])
}

@Test func givenABufferLargerThanTwoChunksWhenAppendedThenAllFullChunksAreEmittedInOrder() {
    // Given
    var chunker = AudioChunker(chunkSize: 2)

    // When
    let chunks = chunker.append([1, 2, 3, 4, 5])

    // Then
    #expect(chunks == [[1, 2], [3, 4]])
}

@Test func givenAPendingRemainderWhenFlushedThenTheRemainderComesOutOnce() {
    // Given
    var chunker = AudioChunker(chunkSize: 4)
    _ = chunker.append([1, 2, 3, 4, 5])

    // When
    let remainder = chunker.flush()
    let secondFlush = chunker.flush()

    // Then
    #expect(remainder == [5])
    #expect(secondFlush == nil)
}

@Test func givenNothingPendingWhenFlushedThenNothingComesOut() {
    // Given
    var chunker = AudioChunker(chunkSize: 4)
    _ = chunker.append([1, 2, 3, 4])

    // When
    let remainder = chunker.flush()

    // Then
    #expect(remainder == nil)
}

@Test func givenAFlushedChunkerWhenNewSamplesArriveThenChunkingStartsFresh() {
    // Given
    var chunker = AudioChunker(chunkSize: 2)
    _ = chunker.append([1])
    _ = chunker.flush()

    // When
    let chunks = chunker.append([7, 8])

    // Then
    #expect(chunks == [[7, 8]])
}
