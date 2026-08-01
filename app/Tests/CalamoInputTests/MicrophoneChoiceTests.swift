import CalamoInput
import Testing

private let headset = AudioInputDevice(uid: "headset-uid", name: "USB Headset")
private let builtIn = AudioInputDevice(uid: "built-in-uid", name: "MacBook Pro Microphone")

@Test func givenNoPinnedDeviceWhenChoosingThenTheSystemDefaultLeads() {
    // Given
    let available = [builtIn, headset]

    // When
    let choice = MicrophoneChoice.choose(pinnedUid: nil, available: available)

    // Then
    #expect(choice == .systemDefault)
}

@Test func givenAPinnedDeviceStillConnectedWhenChoosingThenItIsPinned() {
    // Given
    let available = [builtIn, headset]

    // When
    let choice = MicrophoneChoice.choose(pinnedUid: "headset-uid", available: available)

    // Then
    #expect(choice == .pinned(headset))
}

@Test func givenAPinnedDeviceUnpluggedWhenChoosingThenItIsMissingAndTheDefaultServes() {
    // Given
    let available = [builtIn]

    // When
    let choice = MicrophoneChoice.choose(pinnedUid: "headset-uid", available: available)

    // Then: the pin survives for the device's return; capture falls back
    #expect(choice == .missing(uid: "headset-uid"))
}
