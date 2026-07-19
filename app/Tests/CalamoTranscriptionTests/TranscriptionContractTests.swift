// Serialized: one shared adapter, and concurrent transcriptions on one
// AsrManager are not a supported FluidAudio pattern.
import CalamoCore
import CalamoTranscription
import FluidAudio
import Foundation
import Testing

@Suite(.serialized)
struct TranscriptionPortContract {
    static let sampleRate = 16_000.0

    static let takes = (ReferenceCorpus.contract?.vectors ?? []).filter { $0.silenceSeconds == nil }
    static let silences = (ReferenceCorpus.contract?.vectors ?? []).filter { $0.silenceSeconds != nil }

    static let adapter: Result<FluidAudioTranscription, any Error> = Result {
        try FluidAudioTranscription.load(
            paths: .defaultCache(),
            minSimilarity: ReferenceCorpus.contract?.boost.minSimilarity
                ?? ConservativeBoost.globalMinSimilarity
        )
    }

    @Test func givenTheTrackedContractFileWhenDecodedThenItYieldsTakesAndASilenceVector() throws {
        // Given
        let file = ReferenceCorpus.contractFile

        // When
        let contract = try JSONDecoder().decode(ContractVectors.self, from: Data(contentsOf: file))

        // Then
        #expect(contract.vectors.contains { $0.silenceSeconds == nil })
        #expect(contract.vectors.contains { $0.silenceSeconds != nil })
        #expect(!contract.boost.entries.isEmpty)
        #expect(!contract.neverSpokenTerms.isEmpty)
    }

    @Test(.enabled(if: ReferenceCorpus.isCalibrated), arguments: takes)
    func givenABoostedCorpusTakeWhenTranscribedThenLanguageAndDictionaryTermsMatchTheVector(
        vector: ContractVectors.Vector
    ) throws {
        // Given
        let contract = try #require(ReferenceCorpus.contract)
        let adapter = try Self.adapter.get()
        let audio = try #require(ReferenceCorpus.audioDirectory)
            .appendingPathComponent("\(vector.id).wav")
        let samples = try AudioConverter().resampleAudioFile(path: audio.path)

        // When
        let transcript = try adapter.transcribe(samples: samples, boostList: contract.boostList)

        // Then
        #expect(transcript.language == vector.expectedLanguage)
        for term in vector.expectedTerms ?? [] {
            #expect(appears(term, in: transcript.text), "missing “\(term)” in: \(transcript.text)")
        }
        for term in contract.neverSpokenTerms {
            #expect(
                !appears(term, in: transcript.text),
                "boosting injected “\(term)” into: \(transcript.text)")
        }
    }

    @Test(.enabled(if: ReferenceCorpus.isCalibrated), arguments: silences)
    func givenSilentAudioWhenTranscribedWithTheFullBoostListThenTheTranscriptIsEmpty(
        vector: ContractVectors.Vector
    ) throws {
        // Given
        let contract = try #require(ReferenceCorpus.contract)
        let adapter = try Self.adapter.get()
        let seconds = try #require(vector.silenceSeconds)
        let samples = [Float](repeating: 0, count: Int(Self.sampleRate * seconds))

        // When
        let transcript = try adapter.transcribe(samples: samples, boostList: contract.boostList)

        // Then
        #expect(transcript.text.isEmpty, "silence transcribed as: \(transcript.text)")
    }
}
