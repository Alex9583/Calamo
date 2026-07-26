import AVFoundation

/// Tap buffers → the pipeline's mono 16 kHz f32. One instance per capture:
/// the resampler carries priming state across consecutive buffers.
public final class AudioFormatConverter {
    public static let targetSampleRate: Double = 16_000

    private let monoInputFormat: AVAudioFormat
    private let converter: AVAudioConverter

    public init?(inputFormat: AVAudioFormat) {
        guard inputFormat.commonFormat == .pcmFormatFloat32,
            inputFormat.channelCount > 0,
            let mono = AVAudioFormat(
                standardFormatWithSampleRate: inputFormat.sampleRate, channels: 1),
            let target = AVAudioFormat(
                standardFormatWithSampleRate: Self.targetSampleRate, channels: 1),
            let converter = AVAudioConverter(from: mono, to: target)
        else { return nil }
        monoInputFormat = mono
        self.converter = converter
    }

    public func convert(_ buffer: AVAudioPCMBuffer) -> [Float] {
        guard let mono = downmixedToMono(buffer) else { return [] }
        return resampled(mono)
    }

    private func downmixedToMono(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let source = buffer.floatChannelData,
            let mono = AVAudioPCMBuffer(
                pcmFormat: monoInputFormat, frameCapacity: max(buffer.frameLength, 1))
        else { return nil }
        mono.frameLength = buffer.frameLength
        let mixed = mono.floatChannelData![0]
        let channels = Int(buffer.format.channelCount)
        // Interleaved buffers expose one plane holding every channel in turn.
        let interleaved = buffer.format.isInterleaved
        let gain = 1 / Float(channels)
        for frame in 0..<Int(buffer.frameLength) {
            var sum: Float = 0
            for channel in 0..<channels {
                sum += interleaved ? source[0][frame * channels + channel] : source[channel][frame]
            }
            mixed[frame] = sum * gain
        }
        return mono
    }

    /// Flushes the samples the resampler still holds; call once, at capture
    /// end — the converter cannot stream any further.
    public func drain() -> [Float] {
        guard let output = AVAudioPCMBuffer(pcmFormat: converter.outputFormat, frameCapacity: 4096)
        else { return [] }
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { _, inputStatus in
            inputStatus.pointee = .endOfStream
            return nil
        }
        guard status != .error, let converted = output.floatChannelData else { return [] }
        return Array(UnsafeBufferPointer(start: converted[0], count: Int(output.frameLength)))
    }

    private func resampled(_ mono: AVAudioPCMBuffer) -> [Float] {
        let ratio = Self.targetSampleRate / monoInputFormat.sampleRate
        let capacity = AVAudioFrameCount(Double(mono.frameLength) * ratio) + 64
        guard let output = AVAudioPCMBuffer(pcmFormat: converter.outputFormat, frameCapacity: capacity)
        else { return [] }
        var consumed = false
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { _, inputStatus in
            inputStatus.pointee = consumed ? .noDataNow : .haveData
            defer { consumed = true }
            return consumed ? nil : mono
        }
        guard status != .error, let converted = output.floatChannelData else { return [] }
        return Array(UnsafeBufferPointer(start: converted[0], count: Int(output.frameLength)))
    }
}
