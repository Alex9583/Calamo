// Minimal reader for the private corpus manifest (simple TOML: one-line
// double-quoted strings without escapes, as the recording scripts produce).
// Present only on the reference machine; malformed content fails loudly.
import Foundation

struct CorpusFixture {
    let id: String
    let language: String
    let verbatim: String
    let clean: String
}

struct CorpusManifest {
    let termsInFixtures: [String]
    let termsExtra: [String]
    let fixtures: [CorpusFixture]

    enum ManifestError: Error, CustomStringConvertible {
        case absent(String)
        case malformed(String)

        var description: String {
            switch self {
            case .absent(let path): "private corpus manifest absent at \(path)"
            case .malformed(let what): "malformed corpus manifest: \(what)"
            }
        }
    }

    static func load(from url: URL) throws -> CorpusManifest {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            throw ManifestError.absent(url.path)
        }
        let blocks = text.components(separatedBy: "[[fixture]]")
        guard let header = blocks.first else {
            throw ManifestError.malformed("empty file")
        }
        return CorpusManifest(
            termsInFixtures: try list("terms_in_fixtures", in: header),
            termsExtra: try list("terms_extra", in: header),
            fixtures: try blocks.dropFirst().map(fixture(from:))
        )
    }

    func fixture(_ id: String) throws -> CorpusFixture {
        guard let fixture = fixtures.first(where: { $0.id == id }) else {
            throw ManifestError.malformed("take \(id) absent from the manifest")
        }
        return fixture
    }

    private static func fixture(from block: String) throws -> CorpusFixture {
        CorpusFixture(
            id: try string("id", in: block),
            language: try string("lang", in: block),
            verbatim: try string("verbatim", in: block),
            clean: try string("clean", in: block)
        )
    }

    private static func string(_ key: String, in block: String) throws -> String {
        let prefix = key + " = \""
        for line in block.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix(prefix), trimmed.hasSuffix("\"") else { continue }
            return String(trimmed.dropFirst(prefix.count).dropLast())
        }
        throw ManifestError.malformed("missing \(key) in a fixture block")
    }

    private static func list(_ key: String, in header: String) throws -> [String] {
        guard let open = header.range(of: key + " = ["),
            let close = header.range(of: "]", range: open.upperBound..<header.endIndex)
        else {
            throw ManifestError.malformed("missing \(key) list")
        }
        let body = header[open.upperBound..<close.lowerBound]
        let quoted = body.components(separatedBy: "\"")
            .enumerated()
            .filter { $0.offset % 2 == 1 }
            .map(\.element)
        guard !quoted.isEmpty else {
            throw ManifestError.malformed("empty \(key) list")
        }
        return quoted
    }
}
