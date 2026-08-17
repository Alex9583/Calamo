import Foundation

extension Bundle {
    /// SwiftPM's `module` probes only the bundle root and the build
    /// directory baked at compile time — neither exists on user machines.
    /// Prefer the copy build.sh installs in Contents/Resources; `module`
    /// still serves dev runs and tests.
    static let calamoResources: Bundle = {
        let installed = Bundle.main.resourceURL
            .map { $0.appendingPathComponent("Calamo_Calamo.bundle") }
            .flatMap(Bundle.init(url:))
        return installed ?? .module
    }()
}
