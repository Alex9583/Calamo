import AVFoundation
import CalamoInput
import Testing

private func syntheticBuffer(
    rate: Double, channels: AVAudioChannelCount, frames: AVAudioFrameCount,
    sample: (_ channel: Int, _ frame: Int) -> Float
) -> AVAudioPCMBuffer {
    let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: channels)!
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
    buffer.frameLength = frames
    for channel in 0..<Int(channels) {
        for frame in 0..<Int(frames) {
            buffer.floatChannelData![channel][frame] = sample(channel, frame)
        }
    }
    return buffer
}

private func steadyState(_ samples: [Float], margin: Int = 200) -> ArraySlice<Float> {
    samples.dropFirst(margin).dropLast(margin)
}

@Test func givenA48kMonoBufferOf100msWhenConvertedThenRoughly1600SamplesComeOutAt16k() {
    // Given
    let input = syntheticBuffer(rate: 48_000, channels: 1, frames: 4800) { _, _ in 0.5 }
    let converter = AudioFormatConverter(inputFormat: input.format)!

    // When
    let output = converter.convert(input)

    // Then: the resampler may hold a little priming latency, never more
    #expect(output.count > 1200 && output.count <= 1600)
    #expect(steadyState(output).allSatisfy { abs($0 - 0.5) < 0.01 })
}

@Test func givenAStereoBufferWithOppositeChannelsWhenConvertedThenTheMonoMixIsSilence() {
    // Given
    let input = syntheticBuffer(rate: 48_000, channels: 2, frames: 4800) { channel, _ in
        channel == 0 ? 0.5 : -0.5
    }
    let converter = AudioFormatConverter(inputFormat: input.format)!

    // When
    let output = converter.convert(input)

    // Then
    #expect(steadyState(output).allSatisfy { abs($0) < 0.01 })
}

@Test func givenAStereoBufferWithEqualChannelsWhenConvertedThenTheLevelIsPreserved() {
    // Given
    let input = syntheticBuffer(rate: 48_000, channels: 2, frames: 4800) { _, _ in 0.5 }
    let converter = AudioFormatConverter(inputFormat: input.format)!

    // When
    let output = converter.convert(input)

    // Then: averaged, not summed — equal channels keep their level
    #expect(steadyState(output).allSatisfy { abs($0 - 0.5) < 0.01 })
}

@Test func givenA441kBufferWhenConvertedThenTheOutputFollowsTheRateRatio() {
    // Given
    let input = syntheticBuffer(rate: 44_100, channels: 1, frames: 4410) { _, _ in 0.25 }
    let converter = AudioFormatConverter(inputFormat: input.format)!

    // When
    let output = converter.convert(input)

    // Then
    #expect(output.count > 1200 && output.count <= 1600)
    #expect(steadyState(output).allSatisfy { abs($0 - 0.25) < 0.01 })
}

@Test func givenConsecutiveBuffersWhenConvertedThenTheStreamAccumulatesWithoutRestarting() {
    // Given
    let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)!
    let converter = AudioFormatConverter(inputFormat: format)!

    // When: ten consecutive 100 ms buffers
    var total = 0
    for _ in 0..<10 {
        let input = syntheticBuffer(rate: 48_000, channels: 1, frames: 4800) { _, _ in 0.5 }
        total += converter.convert(input).count
    }

    // Then: cumulative output converges on the rate ratio, minus one priming latency
    #expect(total > 15600 && total <= 16000)
}

@Test func givenAnAlready16kMonoBufferWhenConvertedThenSamplesPassThrough() {
    // Given
    let input = syntheticBuffer(rate: 16_000, channels: 1, frames: 1600) { _, frame in
        Float(frame % 100) / 100
    }
    let converter = AudioFormatConverter(inputFormat: input.format)!

    // When
    let output = converter.convert(input)

    // Then
    #expect(output.count == 1600)
    #expect(zip(output, 0..<1600).allSatisfy { abs($0 - Float($1 % 100) / 100) < 0.001 })
}

@Test func givenAFinishedCaptureWhenTheConverterIsDrainedThenTheResamplerTailCompletesTheStream() {
    // Given
    let input = syntheticBuffer(rate: 48_000, channels: 1, frames: 4800) { _, _ in 0.5 }
    let converter = AudioFormatConverter(inputFormat: input.format)!
    let streamed = converter.convert(input)

    // When
    let tail = converter.drain()

    // Then: 4800 frames at 48 kHz are exactly 1600 at 16 kHz once flushed
    #expect(!tail.isEmpty)
    #expect(abs(streamed.count + tail.count - 1600) <= 5)
}

@Test func givenAnInterleavedStereoBufferWhenConvertedThenChannelsStillAverage() {
    // Given: opposite channels woven into the single interleaved plane
    let format = AVAudioFormat(
        commonFormat: .pcmFormatFloat32, sampleRate: 48_000, channels: 2, interleaved: true)!
    let input = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4800)!
    input.frameLength = 4800
    for frame in 0..<4800 {
        input.floatChannelData![0][frame * 2] = 0.5
        input.floatChannelData![0][frame * 2 + 1] = -0.5
    }
    let converter = AudioFormatConverter(inputFormat: format)!

    // When
    let output = converter.convert(input)

    // Then
    #expect(output.count > 1200)
    #expect(steadyState(output).allSatisfy { abs($0) < 0.01 })
}

@Test func givenANonFloatInputFormatWhenBuildingTheConverterThenItRefuses() {
    // Given
    let int16Format = AVAudioFormat(
        commonFormat: .pcmFormatInt16, sampleRate: 48_000, channels: 1, interleaved: true)!

    // When
    let converter = AudioFormatConverter(inputFormat: int16Format)

    // Then
    #expect(converter == nil)
}
