import CalamoFeedback
import SwiftUI

/// The waveform history is fixed-length so the bars scroll instead of grow.
@MainActor
final class OverlayModel: ObservableObject {
    static let barCount = 24

    @Published var display: OverlayDisplay = .hidden
    @Published var levels = [Float](repeating: 0, count: barCount)

    func show(_ display: OverlayDisplay) {
        if display == .waveform, self.display != .waveform {
            levels = [Float](repeating: 0, count: Self.barCount)
        }
        self.display = display
    }

    func push(level: Float) {
        levels.removeFirst()
        levels.append(level)
    }
}
