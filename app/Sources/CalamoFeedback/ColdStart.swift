/// The ANE cache is keyed to the binary: an executable that changed since
/// the last successful load recompiles on its first load (~1 min), and the
/// labels must say why instead of an anonymous "Loading models…".
public enum ColdStart: Equatable, Sendable {
    case ordinary
    case postUpdate

    /// One message across surfaces: the status line and the refusal notice.
    public static let postUpdateNotice = "Optimizing after update… (~1 min, once)"

    /// No record (first install) or an unreadable identity stays ordinary.
    public static func classify(current: String?, lastCompiled: String?) -> ColdStart {
        guard let current, let lastCompiled else { return .ordinary }
        return current == lastCompiled ? .ordinary : .postUpdate
    }
}
