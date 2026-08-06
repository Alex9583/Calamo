import AVFoundation
import ApplicationServices
import CalamoCore
import CalamoFeedback
import Carbon

/// The ambient facts the engine cannot observe; the controller polls them.
enum MenuBarProbes {
    static func snapshot(engine: EngineState, download: ModelDownloadProgress?) -> MenuBarSnapshot {
        MenuBarSnapshot(
            engine: engine,
            accessibilityGranted: AXIsProcessTrusted(),
            microphoneGranted: microphoneGranted(),
            secureInputActive: IsSecureEventInputEnabled(),
            hotkeyLabel: HotkeyPreference.load().label,
            download: download)
    }

    /// notDetermined counts as granted: the system prompt is still pending
    /// and a ⚠︎ would mislead.
    private static func microphoneGranted() -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .denied, .restricted: false
        default: true
        }
    }
}
