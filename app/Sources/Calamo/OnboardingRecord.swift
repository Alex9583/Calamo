import Foundation

/// The wizard shows once — the flag survives updates so a post-update
/// launch never re-proposes it. CALAMO_ONBOARDING=1 forces it back for
/// checklist walks.
enum OnboardingRecord {
    static let defaultsKey = "onboardingDone"

    static func shouldShow() -> Bool {
        if ProcessInfo.processInfo.environment["CALAMO_ONBOARDING"] == "1" { return true }
        return !UserDefaults.standard.bool(forKey: defaultsKey)
    }

    static func markDone() {
        UserDefaults.standard.set(true, forKey: defaultsKey)
    }
}
