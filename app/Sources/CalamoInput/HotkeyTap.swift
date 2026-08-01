import CoreGraphics

/// The single active event tap. Active — not listen-only — so macOS gates it
/// behind Accessibility alone, never Input Monitoring. The callback answers
/// whether to swallow the event.
///
/// Not Sendable on purpose (strict-concurrency audit): creation and
/// callbacks live on the main run loop; `reenable` may arrive from the
/// push-to-talk queue but only reads `port`, set once in init.
public final class HotkeyTap {
    private let onEvent: (TapEvent) -> Bool
    private var port: CFMachPort!

    /// Nil when the tap cannot be created — Accessibility not granted.
    public init?(onEvent: @escaping (TapEvent) -> Bool) {
        self.onEvent = onEvent
        let interceptedTypes: [CGEventType] = [.keyDown, .keyUp, .flagsChanged]
        let mask = interceptedTypes.reduce(CGEventMask(0)) { $0 | 1 << $1.rawValue }
        guard
            let port = CGEvent.tapCreate(
                tap: .cghidEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: mask,
                callback: { _, type, event, userInfo in
                    Unmanaged<HotkeyTap>.fromOpaque(userInfo!).takeUnretainedValue()
                        .intercept(type: type, event: event)
                },
                userInfo: Unmanaged.passUnretained(self).toOpaque()
            )
        else { return nil }
        self.port = port
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
    }

    public func reenable() {
        CGEvent.tapEnable(tap: port, enable: true)
    }

    private func intercept(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard let tapEvent = Self.tapEvent(type: type, event: event) else {
            return Unmanaged.passUnretained(event)
        }
        return onEvent(tapEvent) ? nil : Unmanaged.passUnretained(event)
    }

    private static func tapEvent(type: CGEventType, event: CGEvent) -> TapEvent? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            return .tapDisabled
        case .flagsChanged:
            return .flagsChanged(
                keyCode: keyCode,
                modifiers: HotkeyModifiers(flags: event.flags),
                fnDown: event.flags.contains(.maskSecondaryFn))
        case .keyDown:
            return .keyDown(keyCode: keyCode)
        case .keyUp:
            return .keyUp(keyCode: keyCode)
        default:
            return nil
        }
    }
}

extension HotkeyModifiers {
    init(flags: CGEventFlags) {
        self = []
        if flags.contains(.maskControl) { insert(.control) }
        if flags.contains(.maskAlternate) { insert(.option) }
        if flags.contains(.maskShift) { insert(.shift) }
        if flags.contains(.maskCommand) { insert(.command) }
    }
}
