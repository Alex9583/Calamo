import AppKit
import CalamoFeedback

/// Discreet capture chimes; ticket 16 surfaces the checkbox — the flag and
/// its on-by-default reading already live here.
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
