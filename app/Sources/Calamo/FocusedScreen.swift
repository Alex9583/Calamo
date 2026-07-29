import AppKit

/// The spec pins the pill to the screen owning the keyboard focus: AX gives
/// the focused window of the frontmost app, NSScreen.main is the fallback.
/// AX coordinates are top-left-origin; Cocoa screens are bottom-left.
@MainActor
enum FocusedScreen {
    static func current() -> NSScreen? {
        focusedWindowCenter().flatMap { center in
            NSScreen.screens.first { $0.frame.contains(center) }
        } ?? NSScreen.main
    }

    private static func focusedWindowCenter() -> NSPoint? {
        guard
            let app = element(of: AXUIElementCreateSystemWide(), kAXFocusedApplicationAttribute),
            let window = element(of: app, kAXFocusedWindowAttribute),
            let origin = point(of: window),
            let size = size(of: window),
            let primary = NSScreen.screens.first
        else { return nil }
        return NSPoint(
            x: origin.x + size.width / 2,
            y: primary.frame.maxY - (origin.y + size.height / 2)
        )
    }

    private static func attribute(of element: AXUIElement, _ name: String) -> CFTypeRef? {
        var raw: CFTypeRef?
        AXUIElementCopyAttributeValue(element, name as CFString, &raw)
        return raw
    }

    private static func element(of parent: AXUIElement, _ attribute: String) -> AXUIElement? {
        guard let raw = Self.attribute(of: parent, attribute),
            CFGetTypeID(raw) == AXUIElementGetTypeID()
        else { return nil }
        return (raw as! AXUIElement)
    }

    private static func axValue(of element: AXUIElement, _ attribute: String) -> AXValue? {
        guard let raw = Self.attribute(of: element, attribute),
            CFGetTypeID(raw) == AXValueGetTypeID()
        else { return nil }
        return (raw as! AXValue)
    }

    private static func point(of window: AXUIElement) -> CGPoint? {
        guard let value = axValue(of: window, kAXPositionAttribute) else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(value, .cgPoint, &point) else { return nil }
        return point
    }

    private static func size(of window: AXUIElement) -> CGSize? {
        guard let value = axValue(of: window, kAXSizeAttribute) else { return nil }
        var size = CGSize.zero
        guard AXValueGetValue(value, .cgSize, &size) else { return nil }
        return size
    }
}
