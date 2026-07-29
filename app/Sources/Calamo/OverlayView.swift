import CalamoFeedback
import SwiftUI

struct OverlayView: View {
    @ObservedObject var model: OverlayModel

    var body: some View {
        if model.display != .hidden {
            content
                .padding(.horizontal, 18)
                .frame(height: 40)
                .background(.black.opacity(0.85), in: Capsule())
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder private var content: some View {
        switch model.display {
        case .hidden:
            EmptyView()
        case .waveform, .waiting:
            WaveformView(levels: model.levels, waiting: model.display == .waiting)
        case .notice(let text):
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
        }
    }
}

/// One bar per metered chunk; waiting freezes the bars and pulses them.
struct WaveformView: View {
    let levels: [Float]
    let waiting: Bool
    @State private var pulsing = false

    var body: some View {
        HStack(spacing: 3) {
            ForEach(levels.indices, id: \.self) { index in
                Capsule()
                    .fill(.white)
                    .frame(width: 3, height: 4 + 24 * CGFloat(levels[index]))
            }
        }
        .animation(.easeOut(duration: 0.12), value: levels)
        .opacity(pulsing ? 0.35 : 1)
        .onAppear { updatePulse() }
        .onChange(of: waiting) { updatePulse() }
    }

    private func updatePulse() {
        if waiting {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        } else {
            withAnimation(.default) { pulsing = false }
        }
    }
}
