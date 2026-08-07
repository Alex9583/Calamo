import CalamoCore

/// The wizard's Models step folds the store run and the loads into one
/// narrative: downloading → optimizing (the one-time compile) → ready.
/// `ensureFinished`: the store converged, so a still-loading engine means
/// the models are compiling for this Mac.
public enum ModelsPhase: Equatable, Sendable {
    case downloading(ModelDownloadProgress?)
    case optimizing
    case ready
    case failed

    public static func derive(
        engine: EngineState, download: ModelDownloadProgress?, ensureFinished: Bool
    ) -> ModelsPhase {
        switch engine {
        case .ready: .ready
        case .unavailable: .failed
        case .loading: ensureFinished ? .optimizing : .downloading(download)
        }
    }
}
