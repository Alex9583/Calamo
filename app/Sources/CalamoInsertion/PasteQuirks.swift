/// Apps whose synthetic Cmd-V is known to do nothing (EMM/Citrix-style
/// paste blocking): the cascade targets simulated keystrokes directly.
/// The real-app matrix of ticket 18 feeds this list.
struct PasteQuirks {
    static let standard = PasteQuirks(pasteBlockedBundleIDs: [])

    let pasteBlockedBundleIDs: Set<String>

    func blocksPaste(bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return pasteBlockedBundleIDs.contains(bundleID)
    }
}
