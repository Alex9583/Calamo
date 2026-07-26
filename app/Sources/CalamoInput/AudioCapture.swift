// @preconcurrency: AVAudioPCMBuffer crosses from the input tap into the
// internal queue; AVFAudio predates Sendable.
@preconcurrency import AVFoundation

/// AVAudioEngine glue: taps the default input and emits ~100 ms mono 16 kHz
/// chunks from an internal serial queue.
///
/// @unchecked: start/stop share their caller's thread (the push-to-talk
/// queue); `chunker` and `converter` are confined to the internal queue.
public final class AudioCapture: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.calamo.audio-capture")
    private var engine: AVAudioEngine?
    private var converter: AudioFormatConverter?
    private var chunker = AudioChunker()

    public init() {}

    public func start(onChunk: @escaping @Sendable ([Float]) -> Void) throws {
        try Self.requireMicrophoneAccess()
        let engine = AVAudioEngine()
        let converter = try Self.makeConverter(for: engine.inputNode)
        resetStream(with: converter)
        installTap(on: engine.inputNode, through: converter, onChunk: onChunk)
        try launch(engine)
    }

    private static func requireMicrophoneAccess() throws {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: break
        case .denied, .restricted: throw CaptureFailure.permissionDenied
        // The app requests access at startup; still unanswered here means
        // the mic cannot serve this dictation.
        default: throw CaptureFailure.micUnavailable
        }
    }

    private static func makeConverter(for input: AVAudioInputNode) throws -> AudioFormatConverter {
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, let converter = AudioFormatConverter(inputFormat: format)
        else { throw CaptureFailure.micUnavailable }
        return converter
    }

    private func resetStream(with converter: AudioFormatConverter) {
        queue.sync {
            chunker = AudioChunker()
            self.converter = converter
        }
    }

    private func installTap(
        on input: AVAudioInputNode, through converter: AudioFormatConverter,
        onChunk: @escaping @Sendable ([Float]) -> Void
    ) {
        let format = input.outputFormat(forBus: 0)
        input.installTap(
            onBus: 0, bufferSize: AVAudioFrameCount(format.sampleRate / 10), format: format
        ) { [weak self] buffer, _ in
            guard let self else { return }
            self.queue.async {
                for chunk in self.chunker.append(converter.convert(buffer)) { onChunk(chunk) }
            }
        }
    }

    private func launch(_ engine: AVAudioEngine) throws {
        engine.prepare()
        do {
            try engine.start()
        } catch {
            engine.inputNode.removeTap(onBus: 0)
            throw CaptureFailure.micUnavailable
        }
        self.engine = engine
    }

    /// Returns the sub-chunk pending samples plus the resampler tail, after
    /// draining the buffers queued before the tap came off.
    public func stop() -> [Float] {
        guard let engine else { return [] }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        self.engine = nil
        return queue.sync {
            var remainder = chunker.flush() ?? []
            if let converter { remainder += converter.drain() }
            converter = nil
            return remainder
        }
    }
}
