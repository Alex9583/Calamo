import CalamoCore
import CalamoFeedback
import SwiftUI

struct ModelsStepView: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        OnboardingStepLayout(
            title: "Models", explanation: "Speech recognition and cleanup run on your Mac."
        ) {
            switch model.phase {
            case .downloading(let progress): downloading(progress)
            case .optimizing: optimizing
            case .ready: GrantedBadge(text: "Models ready")
            case .failed: failed
            }
        }
    }

    @ViewBuilder private func downloading(_ progress: ModelDownloadProgress?) -> some View {
        if let progress {
            ProgressView(
                "Downloading models… (\(progress.ready)/\(progress.total))",
                value: Double(progress.ready), total: Double(progress.total))
        } else {
            ProgressView("Downloading models…")
        }
        ModelSizesList(catalog: model.catalog)
        Text("Downloads resume automatically if interrupted.")
            .font(.callout)
            .foregroundStyle(.secondary)
    }

    private var optimizing: some View {
        VStack(spacing: 8) {
            ProgressView("Optimizing for your Mac…")
            Text("One time only — about a minute.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var failed: some View {
        VStack(spacing: 8) {
            Label("Model download failed — check your connection.", systemImage: "wifi.slash")
            Button("Retry") { model.retryModels() }
        }
    }
}

struct ModelSizesList: View {
    let catalog: [CatalogModel]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(catalog, id: \.name) { entry in
                Text("\(entry.name) — \(ByteSize.label(entry.bytes))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct TrialStepView: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        OnboardingStepLayout(
            title: "Try it",
            explanation: "Click the field, hold \(model.hotkeyLabel) and say “hello everyone”."
        ) {
            TextField("Your dictation lands here", text: $model.trialText, axis: .vertical)
                .lineLimit(3...5)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 360)
            if model.trialSucceeded {
                GrantedBadge(text: "Dictation works — you're all set.")
            }
        }
    }
}
