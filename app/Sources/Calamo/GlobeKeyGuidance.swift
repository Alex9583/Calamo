import Foundation

/// macOS turns a brief Fn press into the 🌐 system action ahead of the
/// event tap; only this system setting stops it.
enum GlobeKeyGuidance {
    static let message =
        "Apple keyboard: set « Press 🌐 key to » to « Do Nothing » so holding Fn only dictates."

    static func systemFnUsage() -> Int? {
        let value = CFPreferencesCopyAppValue(
            "AppleFnUsageType" as CFString, "com.apple.HIToolbox" as CFString)
        return (value as? NSNumber)?.intValue
    }
}
