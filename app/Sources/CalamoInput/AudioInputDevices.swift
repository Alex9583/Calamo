import AVFoundation
import CoreAudio

public struct AudioInputDevice: Equatable, Sendable {
    public let uid: String
    public let name: String

    public init(uid: String, name: String) {
        self.uid = uid
        self.name = name
    }
}

/// Discovery and UID pinning glue over the machine's input devices.
public enum AudioInputDevices {
    public static func list() -> [AudioInputDevice] {
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external], mediaType: .audio, position: .unspecified)
        return session.devices.map { AudioInputDevice(uid: $0.uniqueID, name: $0.localizedName) }
    }

    /// nil when the UID matches no connected device.
    public static func resolve(uid: String) -> AudioDeviceID? {
        var uidRef = uid as CFString
        var deviceID = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslateUIDToDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        let status = withUnsafeMutablePointer(to: &uidRef) { qualifier in
            AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject), &address,
                UInt32(MemoryLayout<CFString>.size), qualifier, &size, &deviceID)
        }
        guard status == noErr, deviceID != kAudioObjectUnknown else { return nil }
        return deviceID
    }
}
