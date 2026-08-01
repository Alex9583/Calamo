import CalamoCore
import CalamoFeedback
import Foundation

/// Saved edits reach the core without a restart; an invalid file keeps the
/// previous dictionary active and surfaces the line to fix.
enum DictionaryHotReload {
    static func start(engine: DictationEngine) -> DictionaryWatcher {
        reload(engine: engine)  // a file already broken at launch notifies too
        let watcher = DictionaryWatcher(file: DictionaryFile.url) { reload(engine: engine) }
        watcher.start()
        return watcher
    }

    private static func reload(engine: DictationEngine) {
        do {
            try engine.reloadDictionary()
        } catch let DictionaryLoadError.Invalid(line, message) {
            notifyInvalid(line: line, message: message)
        } catch {
            NSLog("Calamo: dictionary reload failed: \(error)")
        }
    }

    private static func notifyInvalid(line: UInt32?, message: String) {
        let place = line.map { "Line \($0): " } ?? ""
        UserNotifier.deliver(
            UserNotice(
                title: "Invalid dictionary",
                body: "\(place)\(message) — the previous dictionary stays active.",
                identifier: "calamo.dictionary-invalid"))
    }
}
