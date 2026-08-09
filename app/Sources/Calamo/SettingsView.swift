import CalamoInput
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Section("Shortcut") {
                shortcutRow
                proposalRow
            }
            Section("Microphone") {
                microphonePicker
                missingMicrophoneNote
            }
            Section("Sounds") { soundsToggle }
            Section("Dictionary") { dictionaryButton }
            Section("General") { loginToggle }
            Section("About") {
                versionRow
                attributionText
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 560)
    }

    private var versionRow: some View {
        LabeledContent(
            "Version",
            value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
                as? String ?? "dev")
    }

    private var attributionText: some View {
        Text(
            """
            Speech recognition by NVIDIA's Parakeet models, used under \
            [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) \
            (CoreML conversion by FluidInference). \
            Cleanup by Qwen3.5-2B (Apache-2.0).
            """
        )
        .font(.callout)
        .foregroundStyle(.secondary)
    }

    private var shortcutRow: some View {
        LabeledContent("Hold to dictate") {
            if model.isRecording {
                Text("Press your shortcut… (Esc cancels)")
                    .foregroundStyle(.secondary)
                Button("Cancel") { model.cancelRecording() }
            } else {
                Text(model.binding.label).fontWeight(.medium)
                Button("Change…") { model.beginRecording() }
            }
        }
    }

    @ViewBuilder private var proposalRow: some View {
        if let proposal = model.proposal, !model.isRecording {
            HStack {
                Text("External keyboard detected — \(proposal.label) needs no Fn key.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Use \(proposal.label)") { model.acceptProposal() }
            }
        }
    }

    private var microphonePicker: some View {
        Picker(
            "Input device",
            selection: Binding(
                get: { model.selectedUid }, set: { model.selectMicrophone(uid: $0) })
        ) {
            Text("System default").tag(String?.none)
            ForEach(model.microphones, id: \.uid) { device in
                Text(device.name).tag(String?.some(device.uid))
            }
            if case .missing(let uid) = model.microphoneChoice {
                Text("\(model.missingMicrophoneName ?? uid) (not connected)")
                    .tag(String?.some(uid))
            }
        }
    }

    @ViewBuilder private var missingMicrophoneNote: some View {
        if model.missingMicrophoneName != nil {
            Text("Not connected — the system default microphone is used.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var soundsToggle: some View {
        Toggle(
            "Play dictation start and end sounds",
            isOn: Binding(get: { model.soundsEnabled }, set: { model.setSoundsEnabled($0) }))
    }

    private var dictionaryButton: some View {
        LabeledContent("Enforced spellings and aliases") {
            Button("Open Dictionary…") { DictionaryFile.open() }
        }
    }

    private var loginToggle: some View {
        Toggle(
            "Launch Calamo at login",
            isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
    }
}
