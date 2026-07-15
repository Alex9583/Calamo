// Build-skeleton menu bar app: a static icon whose menu displays the marker
// returned by the stub facade across the FFI.
import AppKit
import CalamoCore
import SwiftUI

@main
struct CalamoApp: App {
    private let buildChainMarker: String

    init() {
        buildChainMarker = DictationEngine().buildChainMarker()
        // stdout is fully buffered on a pipe — flush so CI sees the marker.
        print("calamo build chain marker: \(buildChainMarker)")
        fflush(stdout)
    }

    var body: some Scene {
        MenuBarExtra("Calamo", systemImage: "waveform") {
            Text(buildChainMarker)
            Divider()
            Button("Quit Calamo") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
