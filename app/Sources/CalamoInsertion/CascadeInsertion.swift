import AppKit
import CalamoCore

/// InsertionPort adapter: the full cascade — secure fields refused before
/// anything is touched, paste first, per-app keystroke fallback, and as the
/// last resort the text stays on the pasteboard for a manual Cmd-V.
public final class CascadeInsertion: InsertionPort, @unchecked Sendable {
    private let environment: () -> InsertionEnvironment
    private let paste: SimulatedPasteInsertion
    private let typeSegments: ([KeystrokeSegment]) -> Bool
    private let quirks: PasteQuirks

    public convenience init() {
        self.init(
            environment: InsertionEnvironment.probe,
            paste: SimulatedPasteInsertion(),
            typeSegments: UnicodeKeystrokes.type,
            quirks: .standard)
    }

    init(
        environment: @escaping () -> InsertionEnvironment,
        paste: SimulatedPasteInsertion,
        typeSegments: @escaping ([KeystrokeSegment]) -> Bool,
        quirks: PasteQuirks
    ) {
        self.environment = environment
        self.paste = paste
        self.typeSegments = typeSegments
        self.quirks = quirks
    }

    /// Synchronous for the engine's pipeline thread; probes and pasteboard
    /// work hop to the main queue, typing stays on the caller.
    public func insert(text: String) throws {
        switch onMainSync({ InsertionCascade.plan(self.environment(), quirks: self.quirks) }) {
        case .refuseSecureField:
            throw InsertionError.SecureField
        case .attempt(let steps):
            try run(steps, text: text)
        }
    }

    private func run(_ steps: [CascadeStep], text: String) throws {
        for step in steps {
            if attempt(step, text: text) { return }
        }
        onMainSync { paste.leaveTextForManualPaste(text) }
        throw InsertionError.Failed(message: "cascade exhausted — text left on the pasteboard")
    }

    private func attempt(_ step: CascadeStep, text: String) -> Bool {
        switch step {
        case .simulatedPaste:
            return onMainSync { paste.attempt(text) }
        case .simulatedKeystrokes:
            guard typeSegments(KeystrokeSegments.segments(of: text)) else { return false }
            onMainSync { paste.restoreAbandonedSnapshot() }
            return true
        }
    }
}
