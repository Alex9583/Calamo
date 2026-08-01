import CalamoInput
import CoreAudio
import Foundation

/// The pinned input device UID; nil means the system default microphone.
/// The name rides along so an unplugged pin stays nameable in the picker.
enum MicrophonePreference {
    static let uidKey = "microphoneUid"
    static let nameKey = "microphoneName"

    static var pinnedUid: String? {
        get { UserDefaults.standard.string(forKey: uidKey) }
        set { UserDefaults.standard.set(newValue, forKey: uidKey) }
    }

    static var pinnedName: String? {
        get { UserDefaults.standard.string(forKey: nameKey) }
        set { UserDefaults.standard.set(newValue, forKey: nameKey) }
    }

    /// Resolved at each capture start; a vanished device yields nil and the
    /// capture stays on the system default.
    static func currentDeviceID() -> AudioDeviceID? {
        guard let uid = pinnedUid else { return nil }
        return AudioInputDevices.resolve(uid: uid)
    }
}
