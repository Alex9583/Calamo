import AppKit

/// dictionary.toml in Application Support; the core's repository creates it
/// on first load.
enum DictionaryFile {
    static var url: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "Calamo")
            .appendingPathComponent("dictionary.toml")
    }

    /// The app associated with .toml if any, else TextEdit — never a picker.
    static func open() {
        let workspace = NSWorkspace.shared
        let file = url
        if workspace.urlForApplication(toOpen: file) != nil {
            workspace.open(file)
        } else {
            workspace.open(
                [file],
                withApplicationAt: URL(fileURLWithPath: "/System/Applications/TextEdit.app"),
                configuration: NSWorkspace.OpenConfiguration()
            )
        }
    }
}
