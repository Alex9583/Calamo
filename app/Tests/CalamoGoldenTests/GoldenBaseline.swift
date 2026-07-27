// Baseline snapshot of a golden run: per-take outputs plus the pinned
// environment, stored with the private corpus. Drift in either is a failure
// to diagnose, never a threshold to widen; re-baselining is a deliberate act
// — delete the file, run once, then pass the admission rite
// (docs/golden-suites.md). Same shape as the Rust harness's baseline module.
import Darwin
import Foundation

struct GoldenEnvironment: Codable, Equatable {
    let chip: String
    let memoryGb: Int
    let macos: String
    let pins: [String: String]
}

struct GoldenBaselineFile: Codable {
    let environment: GoldenEnvironment
    let date: String
    let outputs: [String: String]
}

enum GoldenBaseline {
    static func currentEnvironment(pins: [String: String]) -> GoldenEnvironment {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return GoldenEnvironment(
            chip: sysctlString("machdep.cpu.brand_string"),
            memoryGb: Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824),
            macos: "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)",
            pins: pins
        )
    }

    /// The ASR stack every audio-fed suite pins; the resolved graph is the
    /// one source of truth for the FluidAudio version.
    static func transcriptionPins() -> [String: String] {
        [
            "fluidAudio": fluidAudioPin(),
            "asrModels": "parakeet-tdt-0.6b-v3",
            "ctcModels": "parakeet-ctc-110m-coreml",
        ]
    }

    private static func fluidAudioPin() -> String {
        let resolved = repoRoot().appendingPathComponent("app/Package.resolved")
        guard let data = try? Data(contentsOf: resolved),
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let pins = root["pins"] as? [[String: Any]],
            let fluid = pins.first(where: { $0["identity"] as? String == "fluidaudio" }),
            let state = fluid["state"] as? [String: Any],
            let version = state["version"] as? String
        else { return "" }
        let revision = (state["revision"] as? String)?.prefix(8) ?? ""
        return "\(version) (\(revision))"
    }

    /// The workspace lock file is the one source of truth for the inference
    /// crate's pinned version (the GGUF itself is SHA-pinned by the core and
    /// verified at load, so it needs no pin here).
    static func lockedCrateVersion(_ name: String) -> String {
        let lock = repoRoot().appendingPathComponent("core/Cargo.lock")
        guard let text = try? String(contentsOf: lock, encoding: .utf8) else { return "" }
        var lines = text.split(separator: "\n").makeIterator()
        while let line = lines.next() {
            guard line.trimmingCharacters(in: .whitespaces) == "name = \"\(name)\"" else { continue }
            guard let version = lines.next()?.trimmingCharacters(in: .whitespaces),
                version.hasPrefix("version = ")
            else { return "" }
            return version.dropFirst("version = ".count).trimmingCharacters(
                in: CharacterSet(charactersIn: "\""))
        }
        return ""
    }

    private static func repoRoot() -> URL {
        GoldenFixtures.directory.deletingLastPathComponent()
    }

    /// Absent baseline → bootstrap and announce the rite; present baseline →
    /// compare environment and outputs, never rewriting the file.
    static func checkOrBootstrap(
        name: String, environment: GoldenEnvironment, outputs: [String: String]
    ) throws -> [String] {
        let url = baselineURL(name)
        guard let data = try? Data(contentsOf: url) else {
            try bootstrap(url: url, environment: environment, outputs: outputs)
            return []
        }
        let baseline = try JSONDecoder().decode(GoldenBaselineFile.self, from: data)
        return environmentDrift(baseline, current: environment, url: url)
            + outputDrift(baseline, outputs: outputs)
            + missingTakes(baseline, outputs: outputs)
    }

    private static func baselineURL(_ name: String) -> URL {
        GoldenFixtures.directory
            .appendingPathComponent("audio/local/golden")
            .appendingPathComponent(name)
    }

    private static func environmentDrift(
        _ baseline: GoldenBaselineFile, current: GoldenEnvironment, url: URL
    ) -> [String] {
        guard baseline.environment != current else { return [] }
        return [
            "environment drifted from the baseline of \(baseline.date) — any machine "
                + "or stack change invalidates the calibration; re-baseline (delete "
                + "\(url.path)) after reviewing docs/golden-suites.md"
        ]
    }

    private static func outputDrift(
        _ baseline: GoldenBaselineFile, outputs: [String: String]
    ) -> [String] {
        outputs.sorted(by: { $0.key < $1.key }).compactMap { id, output in
            switch baseline.outputs[id] {
            case .none:
                return "\(id): absent from the baseline"
            case .some(let previous) where previous != output:
                return "\(id): output drifted from the baseline (variance is a bug to "
                    + "diagnose):\n  baseline: \(previous)\n  now:      \(output)"
            case .some:
                return nil
            }
        }
    }

    private static func missingTakes(
        _ baseline: GoldenBaselineFile, outputs: [String: String]
    ) -> [String] {
        baseline.outputs.keys.sorted()
            .filter { outputs[$0] == nil }
            .map { "\($0): in the baseline but not in this run" }
    }

    private static func bootstrap(
        url: URL, environment: GoldenEnvironment, outputs: [String: String]
    ) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let file = GoldenBaselineFile(
            environment: environment,
            date: formatter.string(from: Date()),
            outputs: outputs
        )
        try encoder.encode(file).write(to: url)
        print(
            "[golden] baseline bootstrapped at \(url.path) — run the admission rite "
                + "(5 consecutive identical runs) before trusting it")
    }

    private static func sysctlString(_ name: String) -> String {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return "" }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return "" }
        return String(cString: buffer)
    }
}
