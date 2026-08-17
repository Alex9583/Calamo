import CalamoFeedback
import SwiftUI

struct OverlayView: View {
    @ObservedObject var model: OverlayModel

    var body: some View {
        if model.display != .hidden {
            HStack(spacing: 10) {
                QuillView(writing: model.display == .waiting)
                content
            }
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

/// One bar per metered chunk, drifting toward the quill that drinks them;
/// waiting settles the bars into a flat ink line while the quill writes.
struct WaveformView: View {
    let levels: [Float]
    let waiting: Bool

    var body: some View {
        HStack(spacing: 3) {
            ForEach(levels.indices, id: \.self) { index in
                Capsule()
                    .fill(.white)
                    .frame(width: 3, height: 4 + 24 * level(at: index))
            }
        }
        .animation(.easeOut(duration: 0.12), value: levels)
        .animation(.easeOut(duration: 0.3), value: waiting)
    }

    private func level(at index: Int) -> CGFloat {
        waiting ? 0 : CGFloat(levels[index])
    }
}
