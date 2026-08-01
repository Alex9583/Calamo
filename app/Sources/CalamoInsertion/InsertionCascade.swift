/// The pure decision behind « write everywhere, never betray »: which
/// insertion steps to attempt given what the probes saw. Exhausting the
/// attempts is the caller's last resort — text left on the pasteboard.
enum InsertionCascade {
    static func plan(_ environment: InsertionEnvironment, quirks: PasteQuirks) -> CascadePlan {
        if environment.fieldIsSecure || environment.secureInputActive {
            return .refuseSecureField
        }
        if quirks.blocksPaste(bundleID: environment.frontAppBundleID) {
            return .attempt([.simulatedKeystrokes])
        }
        return .attempt([.simulatedPaste, .simulatedKeystrokes])
    }
}

enum CascadePlan: Equatable {
    /// Refused before anything is touched: nothing written, nothing posted.
    case refuseSecureField
    case attempt([CascadeStep])
}

enum CascadeStep: Equatable {
    case simulatedPaste
    case simulatedKeystrokes
}
