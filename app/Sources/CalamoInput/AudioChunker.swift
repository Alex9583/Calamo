/// 1600 samples = 100 ms at 16 kHz.
public struct AudioChunker {
    private var pending: [Float] = []
    private let chunkSize: Int

    public init(chunkSize: Int = 1600) {
        self.chunkSize = chunkSize
    }

    public mutating func append(_ samples: [Float]) -> [[Float]] {
        pending.append(contentsOf: samples)
        var chunks: [[Float]] = []
        while pending.count >= chunkSize {
            chunks.append(Array(pending.prefix(chunkSize)))
            pending.removeFirst(chunkSize)
        }
        return chunks
    }

    public mutating func flush() -> [Float]? {
        defer { pending = [] }
        return pending.isEmpty ? nil : pending
    }
}
