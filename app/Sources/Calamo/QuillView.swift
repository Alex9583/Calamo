import AppKit
import SwiftUI

/// The brand quill anchoring every pill state, nib toward the wave;
/// writing rocks it on its nib like a hand shaping letters.
struct QuillView: View {
    let writing: Bool
    @State private var tilted = false

    private static let ink = Color(red: 0.247, green: 0.659, blue: 0.576)
    /// The nib lands here once the mark is mirrored nib-rightward.
    private static let nib = UnitPoint(x: 0.76, y: 0.75)
    private static let mark: NSImage =
        Bundle.calamoResources.url(forResource: "menubar-template", withExtension: "svg")
        .flatMap { NSImage(contentsOf: $0) }
        ?? NSImage(systemSymbolName: "pencil", accessibilityDescription: "Calamo")
        ?? NSImage()

    var body: some View {
        Image(nsImage: Self.mark)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(height: 26)
            .scaleEffect(x: -1)
            .rotationEffect(.degrees(tilted ? 4 : 0), anchor: Self.nib)
            .foregroundStyle(Self.ink)
            .onAppear { updateTilt() }
            .onChange(of: writing) { updateTilt() }
    }

    private func updateTilt() {
        if writing {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                tilted = true
            }
        } else {
            withAnimation(.default) { tilted = false }
        }
    }
}
