import AppKit

/// Main-queue confined, like every pasteboard touch; the cascade owns the
/// hop.
final class SimulatedPasteInsertion {
    private let pasteboard: NSPasteboard
    private let restoreDelay: TimeInterval
    private let paste: () -> Bool

    convenience init(paste: @escaping () -> Bool) {
        self.init(pasteboard: .general, restoreDelay: 0.3, paste: paste)
    }

    init(pasteboard: NSPasteboard, restoreDelay: TimeInterval, paste: @escaping () -> Bool) {
        self.pasteboard = pasteboard
        self.restoreDelay = restoreDelay
        self.paste = paste
    }

    /// The user's copy, held while our transient text sits on the pasteboard.
    /// `work` is the deferred restore after a successful paste; nil after a
    /// failed one, where restoring waits on the cascade's outcome.
    private struct HeldSnapshot {
        let snapshot: PasteboardSnapshot
        let changeCountAfterWrite: Int
        let work: DispatchWorkItem?
    }

    private var held: HeldSnapshot?

    func attempt(_ text: String) -> Bool {
        let snapshot = snapshotToRestore()
        writeConcealed(text)
        guard paste() else {
            held = HeldSnapshot(
                snapshot: snapshot, changeCountAfterWrite: pasteboard.changeCount, work: nil)
            return false
        }
        scheduleRestore(of: snapshot)
        return true
    }

    /// After a fallback inserted the text another way: the user's copy comes
    /// back, unless someone wrote over our transient text meanwhile.
    func restoreAbandonedSnapshot() {
        guard let held, held.work == nil else { return }
        self.held = nil
        if pasteboard.changeCount == held.changeCountAfterWrite {
            held.snapshot.restore(to: pasteboard)
        }
    }

    /// Last resort: the dictation owns the pasteboard now — written plain so
    /// clipboard managers historize it too, and never restored over.
    func leaveTextForManualPaste(_ text: String) {
        held?.work?.cancel()
        held = nil
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Reuses the held snapshot when a dictation lands before the previous
    /// restore fired — the pasteboard then holds our own transient text, not
    /// the user's copy.
    private func snapshotToRestore() -> PasteboardSnapshot {
        guard let held else {
            return PasteboardSnapshot.capture(from: pasteboard)
        }
        held.work?.cancel()
        self.held = nil
        return pasteboard.changeCount == held.changeCountAfterWrite
            ? held.snapshot
            : PasteboardSnapshot.capture(from: pasteboard)
    }

    private func scheduleRestore(of snapshot: PasteboardSnapshot) {
        let changeCountAfterWrite = pasteboard.changeCount
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.held = nil
            // A moved changeCount means someone wrote since the paste —
            // restoring would clobber the user's newer copy.
            if self.pasteboard.changeCount == changeCountAfterWrite {
                snapshot.restore(to: self.pasteboard)
            }
        }
        held = HeldSnapshot(
            snapshot: snapshot, changeCountAfterWrite: changeCountAfterWrite, work: work)
        DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay, execute: work)
    }

    /// nspasteboard.org convention: transient + concealed keep clipboard
    /// managers from historizing the dictation.
    private func writeConcealed(_ text: String) {
        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        item.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
        item.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
        pasteboard.clearContents()
        pasteboard.writeObjects([item])
    }
}
