// The golden vectors as data: fixtures/*-golden.json carry the literal
// statistical thresholds (never recomputed); takes, languages, boost list
// and never-spoken terms stay owned by the transcription contract file.
import CalamoCore
import Foundation

struct AsrGoldenVectors: Decodable {
    let contract: String
    let aggregateWerBudget: [String: Double]
}

struct E2eGoldenVectors: Decodable {
    let contract: String
    let minSimilarityVsClean: Double
    let maxTakesBelowSimilarity: Int
}

struct TranscriptionContract: Decodable {
    struct Boost: Decodable {
        let minSimilarity: Float
        let entries: [Entry]
    }

    struct Entry: Decodable {
        let text: String
        let aliases: [String]?
    }

    struct Vector: Decodable {
        let id: String
        let language: String?
        let silenceSeconds: Double?
        let expectedTerms: [String]?
    }

    let audioDirectory: String
    let boost: Boost
    let neverSpokenTerms: [String]
    let vectors: [Vector]

    var takes: [Vector] { vectors.filter { $0.silenceSeconds == nil } }

    var boostList: [BoostEntry] {
        boost.entries.map { BoostEntry(canonicalText: $0.text, aliases: $0.aliases ?? []) }
    }

    /// The reference vocabulary as the user's dictionary.toml.
    func dictionaryToml(excluding excluded: Set<String> = []) -> String {
        let lines = boost.entries
            .filter { !excluded.contains($0.text) }
            .map { entry in
                let aliases = (entry.aliases ?? []).map { "\"\($0)\"" }.joined(separator: ", ")
                return aliases.isEmpty
                    ? "    { text = \"\(entry.text)\" },"
                    : "    { text = \"\(entry.text)\", aliases = [\(aliases)] },"
            }
        return "entries = [\n\(lines.joined(separator: "\n"))\n]\n"
    }
}

enum GoldenFixtures {
    static let directory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("fixtures")

    static var repoRoot: URL { directory.deletingLastPathComponent() }

    static func decode<T: Decodable>(_ name: String) throws -> T {
        let url = directory.appendingPathComponent(name)
        return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }

    static func manifest(for contract: TranscriptionContract) throws -> CorpusManifest {
        try CorpusManifest.load(
            from: directory
                .appendingPathComponent(contract.audioDirectory)
                .appendingPathComponent("manifest.toml"))
    }

    static func audioURL(_ id: String, in contract: TranscriptionContract) -> URL {
        directory
            .appendingPathComponent(contract.audioDirectory)
            .appendingPathComponent("\(id).wav")
    }
}

enum GoldenGate {
    // Golden runs are an explicit act on the calibrated reference machine:
    // requested-but-impossible fails loudly instead of skipping.
    static var isRequested: Bool {
        ProcessInfo.processInfo.environment["CALAMO_GOLDEN"] == "1"
    }

    /// Serializes the model-heavy golden suites when one process runs several.
    static let modelLock = NSLock()
}
