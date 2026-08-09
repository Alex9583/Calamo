// Renders the DMG background: the drag-to-/Applications gesture (App
// Translocation makes it mandatory) and the official Gatekeeper path —
// System Settings → Privacy & Security → "Open Anyway". Icon coordinates 
// must stay in sync with scripts/dmg-settings.py.
//
// Usage: swift scripts/render-dmg-background.swift assets
import AppKit

let canvas = NSSize(width: 660, height: 420)
let teal = NSColor(srgbRed: 0x0D / 255, green: 0x6B / 255, blue: 0x5E / 255, alpha: 1)
let paper = NSColor(srgbRed: 0xFA / 255, green: 0xF8 / 255, blue: 0xF3 / 255, alpha: 1)
let ink = NSColor(srgbRed: 0x3B / 255, green: 0x38 / 255, blue: 0x2F / 255, alpha: 1)
let faded = NSColor(srgbRed: 0x8A / 255, green: 0x85 / 255, blue: 0x7C / 255, alpha: 1)
let badgeSize: CGFloat = 22
let badgeGap: CGFloat = 32

func attributes(size: CGFloat, weight: NSFont.Weight, color: NSColor) -> [NSAttributedString.Key: Any] {
    [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color]
}

func drawCentered(_ text: String, top: CGFloat, _ attrs: [NSAttributedString.Key: Any]) {
    let line = NSAttributedString(string: text, attributes: attrs)
    line.draw(at: NSPoint(x: (canvas.width - line.size().width) / 2, y: top))
}

func drawBadge(_ number: Int, x: CGFloat, top: CGFloat) {
    teal.setFill()
    NSBezierPath(ovalIn: NSRect(x: x, y: top, width: badgeSize, height: badgeSize)).fill()
    let digit = NSAttributedString(
        string: "\(number)", attributes: attributes(size: 13, weight: .semibold, color: .white))
    digit.draw(
        at: NSPoint(
            x: x + (badgeSize - digit.size().width) / 2,
            y: top + (badgeSize - digit.size().height) / 2))
}

func drawStep(_ number: Int, _ text: String, top: CGFloat) {
    let line = NSAttributedString(string: text, attributes: attributes(size: 13, weight: .regular, color: ink))
    let x = (canvas.width - (badgeGap + line.size().width)) / 2
    drawBadge(number, x: x, top: top + (line.size().height - badgeSize) / 2)
    line.draw(at: NSPoint(x: x + badgeGap, y: top))
}

func drawArrow() {
    teal.withAlphaComponent(0.45).setStroke()
    teal.withAlphaComponent(0.45).setFill()
    let shaft = NSBezierPath()
    shaft.lineWidth = 3
    shaft.lineCapStyle = .round
    shaft.move(to: NSPoint(x: 245, y: 180))
    shaft.line(to: NSPoint(x: 400, y: 180))
    shaft.stroke()
    let head = NSBezierPath()
    head.move(to: NSPoint(x: 398, y: 171))
    head.line(to: NSPoint(x: 414, y: 180))
    head.line(to: NSPoint(x: 398, y: 189))
    head.close()
    head.fill()
}

func drawBackground() {
    paper.setFill()
    NSRect(origin: .zero, size: canvas).fill()
    drawCentered("Install Calamo", top: 30, attributes(size: 21, weight: .semibold, color: teal))
    drawStep(1, "Drag Calamo into Applications first — never launch it from this window.", top: 72)
    drawArrow()
    drawStep(2, "Open Calamo. macOS cannot verify it — click “Done”.", top: 300)
    drawStep(3, "System Settings → Privacy & Security → “Open Anyway”.", top: 332)
    drawCentered("macOS asks again after every update.", top: 376, attributes(size: 11, weight: .regular, color: faded))
}

func render(scale: Int) -> Data {
    let image = NSImage(size: canvas, flipped: true) { _ in
        drawBackground()
        return true
    }
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(canvas.width) * scale,
        pixelsHigh: Int(canvas.height) * scale, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .calibratedRGB,
        bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = canvas
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(origin: .zero, size: canvas))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: render-dmg-background.swift <out-dir>\n".utf8))
    exit(1)
}
let outDir = URL(fileURLWithPath: CommandLine.arguments[1])
try render(scale: 1).write(to: outDir.appendingPathComponent("dmg-background.png"))
try render(scale: 2).write(to: outDir.appendingPathComponent("dmg-background@2x.png"))
