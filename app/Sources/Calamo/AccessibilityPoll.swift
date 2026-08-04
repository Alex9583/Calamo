import ApplicationServices
import CalamoInput
import Foundation

/// Revocation emits no event, so a poll (menu-bar cadence) keeps the tap's
/// existence in lockstep with the Accessibility grant.
@MainActor
final class AccessibilityPoll {
    private let input: PushToTalkInput
    private var poll: Timer?

    init(input: PushToTalkInput) {
        self.input = input
        poll = repeatOnMain(every: 2) { [weak self] in self?.sync() }
    }

    private func sync() {
        input.syncTap(trusted: AXIsProcessTrusted())
    }
}
