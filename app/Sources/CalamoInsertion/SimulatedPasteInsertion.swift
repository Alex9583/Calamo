import AppKit
import CalamoCore

/// InsertionPort adapter: simulated paste at the cursor — the primary (and
/// for now only) insertion method; the fallback cascade and secure-field
/// refusal arrive with ticket 17.
public final class SimulatedPasteInsertion: InsertionPort, @unchecked Sendable {
    private let pasteboard: NSPasteboard
    private let restoreDelay: TimeInterval
    private let paste: () -> Bool

    public convenience init() {
        self.init(pasteboard: .general, restoreDelay: 0.3, paste: CommandVKeystroke.post)
    }

    init(pasteboard: NSPasteboard, restoreDelay: TimeInterval, paste: @escaping () -> Bool) {
        self.pasteboard = pasteboard
        self.restoreDelay = restoreDelay
        self.paste = paste
    }

    private struct PendingRestore {
        let snapshot: PasteboardSnapshot
        let changeCountAfterWrite: Int
        let work: DispatchWorkItem
    }

    /// Main-queue confined, like every pasteboard touch.
    private var pendingRestore: PendingRestore?

    /// Synchronous for the engine's pipeline thread; the main run loop must
    /// be live.
    public func insert(text: String) throws {
        if Thread.isMainThread {
            return try insertOnMain(text)
        }
        return try DispatchQueue.main.sync { try insertOnMain(text) }
    }

    private func insertOnMain(_ text: String) throws {
        let snapshot = snapshotToRestore()
        writeConcealed(text)
        guard paste() else {
            // Leave the dictation on the pasteboard: recoverable by hand with
            // Cmd-V, where restoring would erase it (notification at ticket 17).
            throw InsertionError.Failed(message: "could not synthesize the paste keystroke")
        }
        scheduleRestore(of: snapshot)
    }

    /// Reuses the held snapshot when a dictation lands before the previous
    /// restore fired — the pasteboard then holds our own transient text, not
    /// the user's copy.
    private func snapshotToRestore() -> PasteboardSnapshot {
        guard let pending = pendingRestore else {
            return PasteboardSnapshot.capture(from: pasteboard)
        }
        pending.work.cancel()
        pendingRestore = nil
        return pasteboard.changeCount == pending.changeCountAfterWrite
            ? pending.snapshot
            : PasteboardSnapshot.capture(from: pasteboard)
    }

    private func scheduleRestore(of snapshot: PasteboardSnapshot) {
        let changeCountAfterWrite = pasteboard.changeCount
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingRestore = nil
            // A moved changeCount means someone wrote since the paste —
            // restoring would clobber the user's newer copy.
            if self.pasteboard.changeCount == changeCountAfterWrite {
                snapshot.restore(to: self.pasteboard)
            }
        }
        pendingRestore = PendingRestore(
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
