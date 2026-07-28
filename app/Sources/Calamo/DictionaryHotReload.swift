import CalamoCore
import Foundation
import UserNotifications

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
        let body = "\(place)\(message) — the previous dictionary stays active."
        // Unbundled (swift test, debug binaries): the notification center
        // is unavailable and would crash.
        guard Bundle.main.bundleIdentifier != nil else {
            return NSLog("Calamo: invalid dictionary — \(body)")
        }
        deliver(body: body)
    }

    private static func deliver(body: String) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { granted, _ in
            guard granted else {
                return NSLog("Calamo: invalid dictionary (notifications denied) — \(body)")
            }
            let content = UNMutableNotificationContent()
            content.title = "Invalid dictionary"
            content.body = body
            // Stable identifier: repeated saves replace, never stack.
            UNUserNotificationCenter.current().add(
                UNNotificationRequest(
                    identifier: "calamo.dictionary-invalid", content: content, trigger: nil))
        }
    }
}
