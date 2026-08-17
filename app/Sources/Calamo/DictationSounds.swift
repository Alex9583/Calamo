import AppKit
import CalamoFeedback

struct DictationSounds {
    static let defaultsKey = "dictationSounds"

    var enabled: Bool {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: Self.defaultsKey) == nil
            || defaults.bool(forKey: Self.defaultsKey)
    }

    func play(_ cue: SoundCue) {
        guard enabled, let sound = Self.sound(for: cue) else { return }
        sound.volume = 0.35
        sound.play()
    }

    /// The first play must not read the disk on the pill path.
    func prewarm() {
        _ = Self.sound(for: .captureStart)
        _ = Self.sound(for: .captureEnd)
    }

    private static func sound(for cue: SoundCue) -> NSSound? {
        NSSound(named: cue == .captureStart ? "Tink" : "Pop")
    }
}
