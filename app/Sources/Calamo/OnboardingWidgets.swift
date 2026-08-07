import SwiftUI

/// One visual grammar for all five steps: title, one-line explanation,
/// then the step's own content.
struct OnboardingStepLayout<Content: View>: View {
    let title: String
    let explanation: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 12) {
            Text(title).font(.title.bold())
            Text(explanation)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            content
        }
    }
}

struct GrantedBadge: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .foregroundStyle(.green)
            .fontWeight(.medium)
    }
}

enum ByteSize {
    static func label(_ bytes: UInt64) -> String {
        if bytes >= 1_000_000_000 {
            return String(format: "%.2f GB", Double(bytes) / 1_000_000_000)
        }
        return String(format: "%.0f MB", Double(bytes) / 1_000_000)
    }
}
