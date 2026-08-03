// The audio-fed golden suites' shared step: a private take through the
// boosted adapter, with the language check every suite applies.
import CalamoTranscription
import FluidAudio
import Foundation

struct TranscribedTake {
    let fixture: CorpusFixture
    let language: String
    let text: String
    let languageFailures: [String]
}

func transcribeTake(
    _ vector: TranscriptionContract.Vector,
    _ adapter: FluidAudioTranscription,
    _ contract: TranscriptionContract,
    _ manifest: CorpusManifest
) throws -> TranscribedTake {
    let fixture = try manifest.fixture(vector.id)
    let samples = try AudioConverter()
        .resampleAudioFile(path: GoldenFixtures.audioURL(vector.id, in: contract).path)
    let transcript = try adapter.transcribe(samples: samples, boostList: contract.boostList)
    let language = languageCode(transcript.language)
    return TranscribedTake(
        fixture: fixture,
        language: language,
        text: transcript.text,
        languageFailures: languageBreach(
            id: vector.id, detected: language, expected: vector.language, in: transcript.text))
}
