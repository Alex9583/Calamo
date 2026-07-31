// Menu bar = persistent: the icon and status line render the engine's
// ambient state; dictation events stay on the overlay.
import CalamoCore

public enum MenuBarIcon: Equatable, Sendable {
    case ready
    case loading
    case unavailable
    case secureInput
}

public enum StatusAction: Equatable, Sendable {
    case openAccessibilitySettings
    case openMicrophoneSettings
    case redownloadModels
}

public struct StatusLine: Equatable, Sendable {
    public let label: String
    public let action: StatusAction?

    public init(label: String, action: StatusAction? = nil) {
        self.label = label
        self.action = action
    }
}

public struct MenuBarSnapshot: Equatable, Sendable {
    public let engine: EngineState
    public let accessibilityGranted: Bool
    public let microphoneGranted: Bool
    public let secureInputActive: Bool

    public init(
        engine: EngineState, accessibilityGranted: Bool, microphoneGranted: Bool,
        secureInputActive: Bool
    ) {
        self.engine = engine
        self.accessibilityGranted = accessibilityGranted
        self.microphoneGranted = microphoneGranted
        self.secureInputActive = secureInputActive
    }
}

public struct MenuBarPresentation: Equatable, Sendable {
    public let icon: MenuBarIcon
    public let status: StatusLine

    public init(icon: MenuBarIcon, status: StatusLine) {
        self.icon = icon
        self.status = status
    }

    public static func derive(from snapshot: MenuBarSnapshot) -> MenuBarPresentation {
        revokedPermission(in: snapshot) ?? derivedFromEngine(snapshot)
    }

    private static func revokedPermission(in snapshot: MenuBarSnapshot) -> MenuBarPresentation? {
        if !snapshot.accessibilityGranted {
            return permissionNeeded("Accessibility", .openAccessibilitySettings)
        }
        if !snapshot.microphoneGranted {
            return permissionNeeded("Microphone", .openMicrophoneSettings)
        }
        return nil
    }

    private static func permissionNeeded(
        _ permission: String, _ action: StatusAction
    ) -> MenuBarPresentation {
        MenuBarPresentation(
            icon: .unavailable,
            status: StatusLine(
                label: "\(permission) permission needed — Open System Settings", action: action))
    }

    private static func derivedFromEngine(_ snapshot: MenuBarSnapshot) -> MenuBarPresentation {
        switch snapshot.engine {
        case .loading:
            MenuBarPresentation(icon: .loading, status: StatusLine(label: "Loading models…"))
        case .unavailable(cause: .modelsMissing):
            MenuBarPresentation(
                icon: .unavailable,
                status: StatusLine(label: "Models missing — Redownload", action: .redownloadModels))
        case .ready where snapshot.secureInputActive:
            MenuBarPresentation(
                icon: .secureInput,
                status: StatusLine(label: "Secure input active — dictation muted"))
        case .ready:
            MenuBarPresentation(
                icon: .ready, status: StatusLine(label: "Ready — hold Fn to dictate"))
        }
    }
}
