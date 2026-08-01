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
        guard enabled, let sound = NSSound(named: cue == .captureStart ? "Tink" : "Pop")
        else { return }
        sound.volume = 0.35
        sound.play()
    }
}
