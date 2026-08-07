import SwiftUI

struct OnboardingView: View {
    @ObservedObject var model: OnboardingModel
    let finish: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            stepContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            footer
        }
        .padding(24)
        .frame(width: 560, height: 420)
    }

    @ViewBuilder private var stepContent: some View {
        switch model.step {
        case .welcome: WelcomeStepView(catalog: model.catalog)
        case .microphone: MicrophoneStepView(model: model)
        case .accessibility: AccessibilityStepView(model: model)
        case .models: ModelsStepView(model: model)
        case .trial: TrialStepView(model: model)
        }
    }

    private var footer: some View {
        HStack {
            Button("Later") { skip() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            Spacer()
            primaryButton
        }
    }

    private func skip() {
        if model.step == .trial { finish() } else { model.advance() }
    }

    @ViewBuilder private var primaryButton: some View {
        switch model.step {
        case .welcome:
            Button("Get Started") { model.advance() }.keyboardShortcut(.defaultAction)
        case .microphone:
            continueButton(enabled: model.microphoneGranted)
        case .accessibility:
            continueButton(enabled: model.accessibilityGranted)
        case .models:
            continueButton(enabled: model.phase == .ready)
        case .trial:
            Button("Finish") { finish() }.keyboardShortcut(.defaultAction)
        }
    }

    private func continueButton(enabled: Bool) -> some View {
        Button("Continue") { model.advance() }
            .keyboardShortcut(.defaultAction)
            .disabled(!enabled)
    }
}
