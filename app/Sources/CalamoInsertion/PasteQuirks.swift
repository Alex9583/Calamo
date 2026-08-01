import Foundation

/// Apps whose synthetic Cmd-V is known to do nothing (EMM/Citrix-style
/// paste blocking): the cascade targets simulated keystrokes directly.
/// The real-app matrix (docs/manual-checklist.md) feeds this list.
struct PasteQuirks {
    static let standard = PasteQuirks(pasteBlockedBundleIDs: [])

    let pasteBlockedBundleIDs: Set<String>

    /// CALAMO_PASTE_BLOCKED=id,id — the checklist's lever to walk the
    /// keystroke fallback in apps whose paste works.
    static func fromEnvironment(
        _ env: [String: String] = ProcessInfo.processInfo.environment
    ) -> PasteQuirks {
        guard let list = env["CALAMO_PASTE_BLOCKED"] else { return .standard }
        let ids = list.split(separator: ",").map(String.init)
        return PasteQuirks(pasteBlockedBundleIDs: standard.pasteBlockedBundleIDs.union(ids))
    }

    func blocksPaste(bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return pasteBlockedBundleIDs.contains(bundleID)
    }
}
