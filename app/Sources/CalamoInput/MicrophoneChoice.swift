/// What the microphone picker shows and the capture targets. A missing
/// pinned device keeps its pin — it may be plugged back — while capture
/// serves from the system default.
public enum MicrophoneChoice: Equatable, Sendable {
    case systemDefault
    case pinned(AudioInputDevice)
    case missing(uid: String)

    public static func choose(
        pinnedUid: String?, available: [AudioInputDevice]
    ) -> MicrophoneChoice {
        guard let pinnedUid else { return .systemDefault }
        guard let device = available.first(where: { $0.uid == pinnedUid }) else {
            return .missing(uid: pinnedUid)
        }
        return .pinned(device)
    }
}
