// The audio-fed golden suites' shared step: a private take through the
// boosted adapter.
import CalamoTranscription
import FluidAudio
import Foundation

struct TranscribedTake {
    let fixture: CorpusFixture
    let text: String
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
    return TranscribedTake(fixture: fixture, text: transcript.text)
}
