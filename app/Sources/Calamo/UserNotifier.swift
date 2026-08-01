import CalamoFeedback
import Foundation
import UserNotifications

/// Delivers UserNotices through Notification Center; logs instead when
/// unbundled (swift test, debug binaries), where the center would crash.
enum UserNotifier {
    static func deliver(_ notice: UserNotice) {
        guard Bundle.main.bundleIdentifier != nil else {
            return NSLog("Calamo: \(notice.title) — \(notice.body)")
        }
        requestThenAdd(notice)
    }

    private static func requestThenAdd(_ notice: UserNotice) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { granted, _ in
            guard granted else {
                return NSLog("Calamo: (notifications denied) \(notice.title) — \(notice.body)")
            }
            let content = UNMutableNotificationContent()
            content.title = notice.title
            content.body = notice.body
            UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: notice.identifier, content: content, trigger: nil)
            )
        }
    }
}
