/// Revoking Accessibility never kills an active tap: it survives untrusted
/// and swallows every keyboard event, so the tap's existence must follow
/// the grant.
public enum TapGuard {
    public enum Verdict: Equatable, Sendable {
        case recreate
        case tearDown
        case keep
    }

    public static func reconcile(trusted: Bool, tapActive: Bool) -> Verdict {
        switch (trusted, tapActive) {
        case (true, false): .recreate
        case (false, true): .tearDown
        default: .keep
        }
    }
}
