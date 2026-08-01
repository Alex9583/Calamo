import AppKit
import Carbon

/// The facts the cascade decides on, read on the main thread at insertion
/// time. Accessibility is only ever read — writing through AX is a locked
/// non-decision (`kAXSelectedTextAttribute` is not writable by decision).
struct InsertionEnvironment {
    let fieldIsSecure: Bool
    let secureInputActive: Bool
    let frontAppBundleID: String?

    static func probe() -> InsertionEnvironment {
        InsertionEnvironment(
            fieldIsSecure: SecureFieldProbe.fieldIsSecure(),
            secureInputActive: IsSecureEventInputEnabled(),
            frontAppBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
    }
}
