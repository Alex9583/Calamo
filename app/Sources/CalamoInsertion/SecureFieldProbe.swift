import ApplicationServices

/// Read-only Accessibility probe: is the focused element a password field?
/// A failed probe (no focus, AX tree off) reads as not-secure — refusing
/// there would mute dictation in every app without an AX tree.
enum SecureFieldProbe {
    static func fieldIsSecure() -> Bool {
        guard let element = focusedElement() else { return false }
        var subrole: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            element, kAXSubroleAttribute as CFString, &subrole)
        return status == .success && (subrole as? String) == kAXSecureTextFieldSubrole
    }

    private static func focusedElement() -> AXUIElement? {
        var focused: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute as CFString, &focused)
        guard status == .success, let focused, CFGetTypeID(focused) == AXUIElementGetTypeID()
        else { return nil }
        return (focused as! AXUIElement)
    }
}
