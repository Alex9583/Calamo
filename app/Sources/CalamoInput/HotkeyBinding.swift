/// The press-and-hold gesture the tap listens for: the Fn key, or a chord of
/// standard modifiers held together.
public enum HotkeyBinding: Equatable, Sendable {
    case fn
    case chord(HotkeyModifiers)

    /// Fn swallowed stays invisible to the frontmost app; chord
    /// flagsChanged pass through — bare modifiers trigger nothing, and
    /// swallowing them would desync the frontmost app's modifier state.
    public var swallowsEvents: Bool {
        self == .fn
    }

    /// macOS decides a brief Fn press ahead of the tap: unless the system
    /// « Press 🌐 key to » is « Do Nothing » (`AppleFnUsageType` 0, absent
    /// meaning the default), the 🌐 action fires despite the swallow.
    public func needsGlobeGuidance(fnUsage: Int?) -> Bool {
        self == .fn && fnUsage != 0
    }

    public var label: String {
        switch self {
        case .fn: "Fn"
        case .chord(let modifiers): modifiers.symbols
        }
    }

    /// Non-Apple external keyboards often keep Fn inside their firmware,
    /// invisible to macOS — offer a chord, but never override a rebind.
    public static func proposal(
        current: HotkeyBinding, hasNonAppleExternalKeyboard: Bool
    ) -> HotkeyBinding? {
        guard current == .fn, hasNonAppleExternalKeyboard else { return nil }
        return .chord([.control, .option])
    }
}

extension HotkeyBinding: RawRepresentable {
    public init?(rawValue: String) {
        if rawValue == "fn" {
            self = .fn
            return
        }
        var modifiers = HotkeyModifiers()
        for name in rawValue.split(separator: "+", omittingEmptySubsequences: false) {
            guard let modifier = HotkeyModifiers.named(String(name)) else { return nil }
            modifiers.insert(modifier)
        }
        guard !modifiers.isEmpty else { return nil }
        self = .chord(modifiers)
    }

    public var rawValue: String {
        switch self {
        case .fn: "fn"
        case .chord(let modifiers): modifiers.names.joined(separator: "+")
        }
    }
}
