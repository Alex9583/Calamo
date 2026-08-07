/// The five skippable steps; "Later" and the primary button both only move
/// forward — no wizard-prison.
enum OnboardingStep: Int, CaseIterable {
    case welcome
    case microphone
    case accessibility
    case models
    case trial

    var next: OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }
}
