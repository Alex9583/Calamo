// The hard per-take assertions the audio-fed suites share.
import CalamoCore

func languageBreach(id: String, detected: String, expected: String?, in text: String) -> [String] {
    guard detected != expected else { return [] }
    return ["\(id): language \(detected), expected \(expected ?? "?") in: \(text)"]
}

/// A never-spoken term may only appear if the take itself dictated it.
func neverSpokenBreaches(_ terms: [String], id: String, output: String, verbatim: String)
    -> [String]
{
    terms
        .filter {
            TextMetrics.termPresent($0, in: output) && !TextMetrics.termPresent($0, in: verbatim)
        }
        .map { "\(id): never-spoken term « \($0) » in: \(output)" }
}

/// A boosted term may appear no more often than the take dictated it
/// (canonical and aliases pooled): any excess is boost-injected.
func injectedTermBreaches(_ entries: [BoostEntry], id: String, output: String, verbatim: String)
    -> [String]
{
    entries.compactMap { entry in
        let forms = dedupedForms(entry)
        let dictated = forms.reduce(0) { $0 + TextMetrics.termCount($1, in: verbatim) }
        let produced = forms.reduce(0) { $0 + TextMetrics.termCount($1, in: output) }
        guard produced > dictated else { return nil }
        return "\(id): boosted « \(entry.canonicalText) » \(produced)× for \(dictated)× "
            + "dictated in: \(output)"
    }
}

func missingTermBreaches(_ terms: [String], id: String, output: String) -> [String] {
    terms
        .filter { !TextMetrics.termPresent($0, in: output) }
        .map { "\(id): expected term « \($0) » missing from: \(output)" }
}

private func dedupedForms(_ entry: BoostEntry) -> [String] {
    var seen = Set<[String]>()
    return ([entry.canonicalText] + entry.aliases)
        .filter { seen.insert(TextMetrics.normAggressive($0)).inserted }
}
