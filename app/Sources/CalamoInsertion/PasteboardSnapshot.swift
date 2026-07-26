import AppKit

/// Byte-for-byte copy of every pasteboard item, so restoration covers rich
/// types (RTF, images, file URLs) and not just plain text.
struct PasteboardSnapshot {
    private let items: [[NSPasteboard.PasteboardType: Data]]

    static func capture(from pasteboard: NSPasteboard) -> PasteboardSnapshot {
        PasteboardSnapshot(
            items: (pasteboard.pasteboardItems ?? []).map { item in
                item.types.reduce(into: [:]) { copied, type in
                    copied[type] = item.data(forType: type)
                }
            })
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        pasteboard.writeObjects(
            items.map { copied in
                let item = NSPasteboardItem()
                for (type, data) in copied {
                    item.setData(data, forType: type)
                }
                return item
            })
    }
}
