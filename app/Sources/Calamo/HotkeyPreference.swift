import CalamoInput
import Foundation

/// The persisted binding; absent or foreign value → Fn, the spec default.
enum HotkeyPreference {
    static let defaultsKey = "hotkeyBinding"

    static func load() -> HotkeyBinding {
        guard let raw = UserDefaults.standard.string(forKey: defaultsKey),
            let binding = HotkeyBinding(rawValue: raw)
        else { return .fn }
        return binding
    }

    static func save(_ binding: HotkeyBinding) {
        UserDefaults.standard.set(binding.rawValue, forKey: defaultsKey)
    }
}
