import SwiftUI

struct MicrophoneStepView: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        OnboardingStepLayout(
            title: "Microphone",
            explanation: "Calamo listens only while you hold the dictation key."
        ) {
            if model.microphoneGranted {
                GrantedBadge(text: "Microphone allowed")
            } else if model.microphoneDenied {
                Button("Open System Settings") { SystemSettings.openMicrophone() }
            } else {
                Button("Allow Microphone Access") { model.requestMicrophone() }
            }
        }
    }
}

struct AccessibilityStepView: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        OnboardingStepLayout(
            title: "Accessibility",
            explanation: "To insert the text at your cursor and listen for the dictation key."
        ) {
            if model.accessibilityGranted {
                GrantedBadge(text: "Accessibility granted")
            } else {
                Button("Open System Settings") { SystemSettings.openAccessibility() }
            }
            if model.needsGlobeKeyGuide { GlobeKeyGuide() }
        }
    }
}

/// Holding Fn otherwise opens the emoji palette on Apple keyboards.
struct GlobeKeyGuide: View {
    var body: some View {
        VStack(spacing: 8) {
            Divider().padding(.vertical, 4)
            Text("Apple keyboard: set « Press 🌐 key to » to « Do Nothing » so holding Fn only dictates.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Open Keyboard Settings") { SystemSettings.openKeyboard() }
        }
    }
}
