import CalamoCore
import SwiftUI

struct WelcomeStepView: View {
    let catalog: [CatalogModel]

    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)
            Text("Welcome to Calamo").font(.largeTitle.bold())
            Text("Hold a key, speak, release — the cleaned-up text lands at your cursor.")
                .multilineTextAlignment(.center)
            Label("100% local — nothing ever leaves your Mac.", systemImage: "lock.shield")
                .foregroundStyle(.secondary)
            Text(downloadNote)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var downloadNote: String {
        let sizes = catalog.map { "\($0.name) (\(ByteSize.label($0.bytes)))" }
            .joined(separator: ", ")
        return "The models are already downloading in the background: \(sizes)."
    }
}
