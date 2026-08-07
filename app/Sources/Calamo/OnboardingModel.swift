import AVFoundation
import ApplicationServices
import CalamoCore
import CalamoFeedback
import Combine

/// Wizard state and actions; grants have no event, so a poll keeps the
/// checkmarks live while the window is up. The view only renders and
/// forwards.
@MainActor
final class OnboardingModel: ObservableObject {
    @Published private(set) var step = OnboardingStep.welcome
    @Published private(set) var microphoneGranted = false
    @Published private(set) var microphoneDenied = false
    @Published private(set) var accessibilityGranted = false
    @Published private(set) var phase = ModelsPhase.downloading(nil)
    @Published private(set) var trialDictated = false
    @Published var trialText = ""

    let catalog = modelCatalog()
    let hotkeyLabel = HotkeyPreference.load().label
    let needsGlobeKeyGuide = !KeyboardDetection.hasNonAppleExternalKeyboard()
    var retryModels: () -> Void = {}

    private var engine = EngineState.loading
    private var download: ModelDownloadProgress?
    private var ensureFinished = false
    private var poll: Timer?

    init() {
        refreshPermissions()
        poll = repeatOnMain(every: 1) { [weak self] in self?.refreshPermissions() }
    }

    /// The badge claims the whole chain worked, so it needs a completed
    /// dictation with text landed — typed text alone proves nothing.
    var trialSucceeded: Bool {
        trialDictated && !trialText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func dictationCompleted() {
        if step == .trial { trialDictated = true }
    }

    func advance() {
        if let next = step.next { step = next }
    }

    func requestMicrophone() {
        AVCaptureDevice.requestAccess(for: .audio) { _ in
            onMain { [weak self] in self?.refreshPermissions() }
        }
    }

    func engineChanged(_ state: EngineState) {
        engine = state
        derivePhase()
    }

    /// nil is the store's "ensure finished" signal: what loads after it is
    /// the one-time compile, not the download.
    func downloadChanged(_ progress: ModelDownloadProgress?) {
        download = progress
        ensureFinished = progress == nil
        derivePhase()
    }

    func stop() {
        poll?.invalidate()
        poll = nil
    }

    private func derivePhase() {
        phase = ModelsPhase.derive(
            engine: engine, download: download, ensureFinished: ensureFinished)
    }

    private func refreshPermissions() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        microphoneGranted = status == .authorized
        microphoneDenied = status == .denied || status == .restricted
        accessibilityGranted = AXIsProcessTrusted()
    }
}
