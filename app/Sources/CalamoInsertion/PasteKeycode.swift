import Carbon

/// Resolves the key that types "v" under the active keyboard layout — a
/// hard-coded ANSI keycode pastes garbage on layouts that move the key
/// (e.g. Dvorak). TIS is main-thread bound, like the rest of the adapter.
enum PasteKeycode {
    static func commandV() -> CGKeyCode {
        resolveV() ?? CGKeyCode(kVK_ANSI_V)
    }

    static func resolveV() -> CGKeyCode? {
        (0..<CGKeyCode(128)).first { character(for: $0) == "v" }
    }

    static func character(for keyCode: CGKeyCode) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
            let rawLayoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let layoutData = Unmanaged<CFData>.fromOpaque(rawLayoutData).takeUnretainedValue() as Data
        var deadKeyState: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)
        let status = layoutData.withUnsafeBytes { buffer -> OSStatus in
            guard let layout = buffer.bindMemory(to: UCKeyboardLayout.self).baseAddress else {
                return OSStatus(paramErr)
            }
            return UCKeyTranslate(
                layout, keyCode, UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState, characters.count, &length, &characters)
        }
        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: characters, count: length)
    }
}
