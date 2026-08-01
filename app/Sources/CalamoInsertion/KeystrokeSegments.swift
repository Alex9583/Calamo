/// Pure segmentation for the simulated-keystroke fallback.
/// CGEventKeyboardSetUnicodeString truncates past ~20 UTF-16 units
/// (enigo #68) and silently drops chunks starting with a control character
/// (enigo #260): text chunks stay short and control characters travel as
/// key presses.
enum KeystrokeSegments {
    static let maxChunkUnits = 20

    static func segments(of text: String) -> [KeystrokeSegment] {
        var segments: [KeystrokeSegment] = []
        var chunk = ""
        for character in text {
            if let key = controlKey(for: character) {
                flushChunk(&chunk, into: &segments)
                segments.append(.key(key))
            } else {
                if chunk.utf16.count + character.utf16.count > maxChunkUnits {
                    flushChunk(&chunk, into: &segments)
                }
                chunk.append(character)
            }
        }
        flushChunk(&chunk, into: &segments)
        return segments
    }

    /// "\r\n" is a single Character: CRLF collapses to one Return press.
    private static func controlKey(for character: Character) -> ControlKey? {
        switch character {
        case "\n", "\r", "\r\n": .newline
        case "\t": .tab
        default: nil
        }
    }

    private static func flushChunk(_ chunk: inout String, into segments: inout [KeystrokeSegment]) {
        guard !chunk.isEmpty else { return }
        segments.append(.text(chunk))
        chunk = ""
    }
}

enum KeystrokeSegment: Equatable {
    case text(String)
    case key(ControlKey)
}

enum ControlKey: Equatable {
    case newline
    case tab
}
