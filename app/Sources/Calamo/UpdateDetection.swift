import CalamoFeedback
import Foundation

/// Persists which binary last completed a model load: a mismatch at launch
/// means this start recompiles the ANE caches, and the UI says why.
enum UpdateDetection {
    static let defaultsKey = "aneCompiledIdentity"

    static func coldStart() -> ColdStart {
        ColdStart.classify(
            current: BinaryIdentity.current(),
            lastCompiled: UserDefaults.standard.string(forKey: defaultsKey))
    }

    /// Only after a successful load — an aborted compile must keep the
    /// post-update label for the next launch.
    static func recordCompiled() {
        guard let current = BinaryIdentity.current() else { return }
        UserDefaults.standard.set(current, forKey: defaultsKey)
    }
}
