import AVFoundation
import CalamoInput
import Combine

/// Settings decisions and persistence; the view only renders and forwards.
/// Rebinds reach the tap immediately, microphone pins resolve at the next
/// capture start.
@MainActor
final class SettingsModel: ObservableObject {
    @Published private(set) var binding = HotkeyPreference.load()
    @Published private(set) var isRecording = false
    @Published private(set) var proposal: HotkeyBinding?
    @Published private(set) var microphones: [AudioInputDevice] = []
    @Published private(set) var microphoneChoice = MicrophoneChoice.systemDefault
    @Published private(set) var soundsEnabled = DictationSounds().enabled
    @Published private(set) var launchAtLogin = LoginItem.isEnabled

    private let input: PushToTalkInput

    init(input: PushToTalkInput) {
        self.input = input
        observeDeviceChanges()
    }

    func refresh() {
        refreshMicrophones()
        proposal = HotkeyBinding.proposal(
            current: binding,
            hasNonAppleExternalKeyboard: KeyboardDetection.hasNonAppleExternalKeyboard())
    }

    func beginRecording() {
        guard !isRecording else { return }
        isRecording = true
        input.beginBindingRecording { [weak self] verdict in
            onMain { self?.recordingEnded(verdict) }
        }
    }

    func cancelRecording() {
        guard isRecording else { return }
        input.cancelBindingRecording()
        isRecording = false
    }

    func acceptProposal() {
        if let proposal { apply(proposal) }
    }

    func selectMicrophone(uid: String?) {
        MicrophonePreference.pinnedUid = uid
        MicrophonePreference.pinnedName = uid.flatMap { picked in
            microphones.first { $0.uid == picked }?.name
        }
        refreshMicrophones()
    }

    func setSoundsEnabled(_ enabled: Bool) {
        soundsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: DictationSounds.defaultsKey)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LoginItem.setEnabled(enabled)
            launchAtLogin = enabled
        } catch {
            NSLog("Calamo: login item toggle failed: \(error)")
            launchAtLogin = LoginItem.isEnabled
        }
    }

    var selectedUid: String? {
        switch microphoneChoice {
        case .systemDefault: nil
        case .pinned(let device): device.uid
        case .missing(let uid): uid
        }
    }

    var missingMicrophoneName: String? {
        guard case .missing = microphoneChoice else { return nil }
        return MicrophonePreference.pinnedName ?? "Selected microphone"
    }

    private func recordingEnded(_ verdict: BindingRecorder.Verdict) {
        isRecording = false
        if case .captured(let captured) = verdict { apply(captured) }
    }

    private func apply(_ newBinding: HotkeyBinding) {
        HotkeyPreference.save(newBinding)
        input.rebind(to: newBinding)
        binding = newBinding
        proposal = nil
    }

    private func refreshMicrophones() {
        microphones = AudioInputDevices.list()
        microphoneChoice = MicrophoneChoice.choose(
            pinnedUid: MicrophonePreference.pinnedUid, available: microphones)
    }

    private func observeDeviceChanges() {
        let names: [Notification.Name] = [
            AVCaptureDevice.wasConnectedNotification, AVCaptureDevice.wasDisconnectedNotification,
        ]
        for name in names {
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) {
                [weak self] _ in
                onMain { self?.refreshMicrophones() }
            }
        }
    }
}
