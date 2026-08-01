public enum HotkeyEvent: Equatable, Sendable {
    case hotkeyChanged(isDown: Bool)
    case otherKey
    case tapDisabled
}

public enum HotkeyAction: Equatable, Sendable {
    case beginDictation
    case endDictation
    case reenableTap
}

public struct HotkeyReaction: Equatable, Sendable {
    public static let passthrough = HotkeyReaction(actions: [], swallowsEvent: false)

    public let actions: [HotkeyAction]
    public let swallowsEvent: Bool

    public init(actions: [HotkeyAction], swallowsEvent: Bool) {
        self.actions = actions
        self.swallowsEvent = swallowsEvent
    }
}

/// Pure press-and-hold decisions; the tap glue owns the OS side effects.
public struct PushToTalkMachine: Sendable {
    private var isHolding = false

    public init() {}

    public mutating func handle(_ event: HotkeyEvent) -> HotkeyReaction {
        switch event {
        case .hotkeyChanged(isDown: true):
            defer { isHolding = true }
            return HotkeyReaction(actions: isHolding ? [] : [.beginDictation], swallowsEvent: true)
        case .hotkeyChanged(isDown: false):
            defer { isHolding = false }
            return HotkeyReaction(actions: isHolding ? [.endDictation] : [], swallowsEvent: true)
        case .otherKey:
            return .passthrough
        case .tapDisabled:
            // The release may have been lost while the tap was off: end, never hang.
            defer { isHolding = false }
            return HotkeyReaction(
                actions: isHolding ? [.reenableTap, .endDictation] : [.reenableTap],
                swallowsEvent: false
            )
        }
    }
}
