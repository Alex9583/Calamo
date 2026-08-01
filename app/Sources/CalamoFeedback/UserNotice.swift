/// A user notification — the surface for failures that require an action,
/// unlike the overlay (events) and the menu bar (ambient state).
public struct UserNotice: Equatable, Sendable {
    public let title: String
    public let body: String
    /// Stable per cause: repeats replace the pending one, never stack.
    public let identifier: String

    public init(title: String, body: String, identifier: String) {
        self.title = title
        self.body = body
        self.identifier = identifier
    }
}
