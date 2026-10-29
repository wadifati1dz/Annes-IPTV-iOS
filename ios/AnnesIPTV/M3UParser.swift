import Foundation

/// Reads M3U / M3U8 playlist text into channels. Tolerant by design: a malformed entry is skipped,
/// never fatal, and duplicate stream URLs are dropped.
enum M3UParser {
    private static let attributePattern = try! NSRegularExpression(pattern: "([A-Za-z0-9_-]+)=\"([^\"]*)\"")

    static func parse(_ text: String) -> [Channel] {
        var channels: [Channel] = []
        var seen = Set<String>()
        var pending: (attrs: [String: String], name: String)?

        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if line.hasPrefix("#EXTINF") {
                pending = parseInfo(line)
            } else if line.hasPrefix("#") {
                continue
            } else if let entry = pending, line.lowercased().hasPrefix("http") {
                pending = nil
                guard !seen.contains(line) else { continue }
                seen.insert(line)
                let attrs = entry.attrs
                let name = entry.name.isEmpty ? (attrs["tvg-name"] ?? "") : entry.name
                guard !name.isEmpty else { continue }
                channels.append(
                    Channel(
                        name: name,
                        url: line,
                        logo: attrs["tvg-logo"].flatMap { $0.isEmpty ? nil : $0 },
                        tvgId: attrs["tvg-id"].flatMap { $0.isEmpty ? nil : $0 },
                        country: attrs["tvg-country"].flatMap { $0.isEmpty ? nil : $0 },
                        language: attrs["tvg-language"].flatMap { $0.isEmpty ? nil : $0 },
                        group: attrs["group-title"].flatMap { $0.isEmpty ? nil : $0 }
                    )
                )
            }
        }
        return channels
    }

    private static func parseInfo(_ line: String) -> (attrs: [String: String], name: String) {
        var attrs: [String: String] = [:]
        let range = NSRange(line.startIndex..., in: line)
        attributePattern.enumerateMatches(in: line, range: range) { match, _, _ in
            guard let match,
                  let key = Range(match.range(at: 1), in: line),
                  let value = Range(match.range(at: 2), in: line) else { return }
            attrs[String(line[key]).lowercased()] = String(line[value])
        }
        // The display name is what follows the last comma that is outside the quoted attributes.
        let tail: Substring
        if let lastQuote = line.lastIndex(of: "\""), let comma = line[lastQuote...].firstIndex(of: ",") {
            tail = line[line.index(after: comma)...]
        } else if let comma = line.lastIndex(of: ",") {
            tail = line[line.index(after: comma)...]
        } else {
            tail = ""
        }
        return (attrs, tail.trimmingCharacters(in: .whitespaces))
    }
}
