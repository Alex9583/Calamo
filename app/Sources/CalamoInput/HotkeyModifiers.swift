public struct HotkeyModifiers: OptionSet, Hashable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let control = HotkeyModifiers(rawValue: 1 << 0)
    public static let option = HotkeyModifiers(rawValue: 1 << 1)
    public static let shift = HotkeyModifiers(rawValue: 1 << 2)
    public static let command = HotkeyModifiers(rawValue: 1 << 3)

    /// System display order: ⌃⌥⇧⌘.
    private static let ordered: [(HotkeyModifiers, symbol: String, name: String)] = [
        (.control, "⌃", "control"), (.option, "⌥", "option"),
        (.shift, "⇧", "shift"), (.command, "⌘", "command"),
    ]

    static func named(_ name: String) -> HotkeyModifiers? {
        ordered.first { $0.name == name }?.0
    }

    var symbols: String {
        Self.ordered.filter { contains($0.0) }.map(\.symbol).joined()
    }

    var names: [String] {
        Self.ordered.filter { contains($0.0) }.map(\.name)
    }
}
