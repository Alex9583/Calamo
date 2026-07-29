import CalamoFeedback
import Foundation
import Testing

private func sine(amplitude: Float, samples: Int = 1600) -> [Float] {
    (0..<samples).map { amplitude * sin(2 * .pi * 440 * Float($0) / 16_000) }
}

@Test func givenSilenceWhenMeteredThenTheLevelIsZero() {
    // Given
    let samples = [Float](repeating: 0, count: 1600)

    // When
    let level = MicLevel.normalized(samples: samples)

    // Then
    #expect(level == 0)
}

@Test func givenNoSamplesWhenMeteredThenTheLevelIsZero() {
    // Given
    let samples: [Float] = []

    // When
    let level = MicLevel.normalized(samples: samples)

    // Then
    #expect(level == 0)
}

@Test func givenAFullScaleToneWhenMeteredThenTheLevelNearsOne() {
    // Given
    let samples = sine(amplitude: 1)

    // When
    let level = MicLevel.normalized(samples: samples)

    // Then
    #expect(level > 0.9 && level <= 1)
}

@Test func givenAQuietAndALoudToneWhenMeteredThenTheLoudOneMetersHigher() {
    // Given
    let quiet = sine(amplitude: 0.01)
    let loud = sine(amplitude: 0.5)

    // When
    let quietLevel = MicLevel.normalized(samples: quiet)
    let loudLevel = MicLevel.normalized(samples: loud)

    // Then
    #expect(quietLevel > 0)
    #expect(loudLevel > quietLevel)
}
