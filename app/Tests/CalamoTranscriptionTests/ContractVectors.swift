// The TranscriptionPort contract as data: fixtures/transcription-contract.json
// names the takes and expectations; the contract only runs where the corpus and
// the local models exist (the calibrated reference machine) and self-skips
// everywhere else, CI included.
import CalamoCore
import CalamoTranscription
import FluidAudio
import Foundation
import Testing

struct ContractVectors: Decodable, Sendable {
    struct Boost: Decodable, Sendable {
        let minSimilarity: Float
        let entries: [Entry]
    }

    struct Entry: Decodable, Sendable {
        let text: String
        let aliases: [String]?
    }

    struct Vector: Decodable, Sendable, CustomTestStringConvertible {
        let id: String
        let expectedTerms: [String]?
        let silenceSeconds: Double?

        var testDescription: String { id }
    }

    let audioDirectory: String
    let boost: Boost
    let neverSpokenTerms: [String]
    let vectors: [Vector]

    var boostList: [BoostEntry] {
        boost.entries.map { BoostEntry(canonicalText: $0.text, aliases: $0.aliases ?? []) }
    }
}

enum ReferenceCorpus {
    static let fixturesDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("fixtures")

    static let contractFile = fixturesDirectory.appendingPathComponent("transcription-contract.json")

    // A broken vectors file must not silently skip the contract: the decode
    // guard test re-reads it loudly, on every machine.
    static let contract: ContractVectors? = {
        guard let data = try? Data(contentsOf: contractFile) else { return nil }
        return try? JSONDecoder().decode(ContractVectors.self, from: data)
    }()

    static var audioDirectory: URL? {
        contract.map { fixturesDirectory.appendingPathComponent($0.audioDirectory) }
    }

    static var isCalibrated: Bool {
        guard let contract, let audioDirectory else { return false }
        let corpusPresent = contract.vectors
            .filter { $0.silenceSeconds == nil }
            .allSatisfy {
                FileManager.default.fileExists(
                    atPath: audioDirectory.appendingPathComponent("\($0.id).wav").path)
            }
        let paths = TranscriptionModelPaths.defaultCache()
        let asrPresent = AsrModels.modelsExist(at: paths.asrModels)
        let ctcPresent = FileManager.default.fileExists(
            atPath: paths.ctcModels.appendingPathComponent("AudioEncoder.mlmodelc").path)
        return corpusPresent && asrPresent && ctcPresent
    }
}

// Word-boundary match so "merged"/"branches" never count as "merge"/"branch".
func appears(_ term: String, in text: String) -> Bool {
    let words = term.split(separator: " ").map { NSRegularExpression.escapedPattern(for: String($0)) }
    let pattern = "\\b" + words.joined(separator: "\\s+") + "\\b"
    return text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
}
