import CoreGraphics

/// The single active event tap. Active — not listen-only — so macOS gates it
/// behind Accessibility alone, never Input Monitoring (spec risk #5).
///
/// Not Sendable on purpose (strict-concurrency audit, J2): creation and
/// callbacks live on the main run loop; `reenable` may arrive from the
/// push-to-talk queue but only reads `port`, set once in init.
public final class FnKeyTap {
    private static let fnKeyCode: Int64 = 63  // kVK_Function

    private let onEvent: (HotkeyEvent) -> HotkeyReaction
    private var port: CFMachPort!

    /// Nil when the tap cannot be created — Accessibility not granted.
    public init?(onEvent: @escaping (HotkeyEvent) -> HotkeyReaction) {
        self.onEvent = onEvent
        let interceptedTypes: [CGEventType] = [.keyDown, .keyUp, .flagsChanged]
        let mask = interceptedTypes.reduce(CGEventMask(0)) { $0 | 1 << $1.rawValue }
        guard let port = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                Unmanaged<FnKeyTap>.fromOpaque(userInfo!).takeUnretainedValue()
                    .intercept(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return nil }
        self.port = port
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
    }

    public func reenable() {
        CGEvent.tapEnable(tap: port, enable: true)
    }

    private func intercept(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let reaction = onEvent(Self.hotkeyEvent(type: type, event: event))
        return reaction.swallowsEvent ? nil : Unmanaged.passUnretained(event)
    }

    private static func hotkeyEvent(type: CGEventType, event: CGEvent) -> HotkeyEvent {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            return .tapDisabled
        case .flagsChanged where event.getIntegerValueField(.keyboardEventKeycode) == fnKeyCode:
            return .fnChanged(isDown: event.flags.contains(.maskSecondaryFn))
        default:
            return .otherKey
        }
    }
}
