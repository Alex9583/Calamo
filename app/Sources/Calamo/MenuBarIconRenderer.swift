import AppKit
import CalamoFeedback

/// Template images keep only alpha, so badges punch a transparent hole in
/// the glyph to stay legible at 18 pt.
@MainActor
enum MenuBarIconRenderer {
    private static let size = NSSize(width: 18, height: 18)

    static func image(for icon: MenuBarIcon) -> NSImage {
        switch icon {
        case .ready, .loading: quill
        case .unavailable: warning
        case .secureInput: padlock
        }
    }

    private static let quill = baseGlyph()
    private static let warning = badged(symbol: "exclamationmark.triangle.fill")
    private static let padlock = badged(symbol: "lock.fill")

    private static func baseGlyph() -> NSImage {
        let image =
            Bundle.module.url(forResource: "menubar-template", withExtension: "svg")
            .flatMap { NSImage(contentsOf: $0) }
            ?? NSImage(systemSymbolName: "waveform", accessibilityDescription: "Calamo")
            ?? NSImage()
        image.size = size
        image.isTemplate = true
        return image
    }

    private static func badged(symbol: String) -> NSImage {
        let glyph = quill
        let badge = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 9, weight: .bold))
        let image = NSImage(size: size, flipped: false) { rect in
            glyph.draw(in: rect)
            guard let badge else { return true }
            let corner = NSRect(x: rect.maxX - 10, y: 0, width: 10, height: 10)
            punch(hole: corner.insetBy(dx: -1.5, dy: -1.5))
            badge.draw(in: fitted(badge.size, in: corner))
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func punch(hole: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.setBlendMode(.destinationOut)
        NSColor.black.setFill()
        NSBezierPath(ovalIn: hole).fill()
        context.setBlendMode(.normal)
    }

    private static func fitted(_ size: NSSize, in rect: NSRect) -> NSRect {
        let scale = min(rect.width / size.width, rect.height / size.height)
        let fit = NSSize(width: size.width * scale, height: size.height * scale)
        return NSRect(
            x: rect.midX - fit.width / 2, y: rect.midY - fit.height / 2,
            width: fit.width, height: fit.height)
    }
}
