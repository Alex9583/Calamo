import Foundation

/// The definitive model root: moving installed models would re-trigger ANE
/// compilation, so this path is decided once, before the first byte lands.
/// CALAMO_MODELS_DIR redirects the whole store for dev and checklist walks.
enum ModelStoreLocation {
    static func root() -> URL {
        if let override = ProcessInfo.processInfo.environment["CALAMO_MODELS_DIR"] {
            return URL(fileURLWithPath: override)
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "Calamo")
            .appendingPathComponent("models")
    }
}
