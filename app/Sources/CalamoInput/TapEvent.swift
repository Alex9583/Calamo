/// A CGEventTap event reduced to what hotkey decisions need.
public enum TapEvent: Equatable, Sendable {
    case flagsChanged(keyCode: Int64, modifiers: HotkeyModifiers, fnDown: Bool)
    case keyDown(keyCode: Int64)
    case keyUp(keyCode: Int64)
    case tapDisabled
}

enum KeyCode {
    static let escape: Int64 = 53  // kVK_Escape
    static let fn: Int64 = 63  // kVK_Function
}
