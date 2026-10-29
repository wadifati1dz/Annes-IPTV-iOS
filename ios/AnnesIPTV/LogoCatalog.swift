import Foundation

/// Logos for channels whose playlist carries none, from the iptv-org database (`logos.json`, keyed by
/// the channel id that `tvg-id` starts with). The 5 MB source is parsed once into a compact cache in
/// the app's caches folder and refreshed weekly; every failure is swallowed, so without a network
/// channels simply keep the initials badge. Only raster logos are indexed.
struct LogoIndex {
    fileprivate(set) var byId: [String: String] = [:]
    fileprivate(set) var byName: [String: String] = [:]

    func apply(to channel: Channel) -> Channel {
        guard channel.logo == nil || channel.logo?.isEmpty == true else { return channel }
        var copy = channel
        if let id = channel.tvgId?.split(separator: "@").first.map({ String($0).lowercased() }),
           let url = byId[id] {
            copy.logo = url
        } else if let url = byName[LogoIndex.normalize(channel.name)] {
            copy.logo = url
        }
        return copy
    }

    static func normalize(_ text: String) -> String {
        String(text.lowercased().filter { $0.isLetter || $0.isNumber })
    }

    fileprivate static func make(from byId: [String: String]) -> LogoIndex {
        var index = LogoIndex()
        index.byId = byId
        // Names map to an id only when exactly one id carries that name, so it never guesses.
        var seen: [String: String?] = [:]
        for (id, url) in byId {
            let base = String(id.split(separator: ".").first ?? "")
            let key = normalize(base)
            if key.count < 3 { continue }
            if seen[key] != nil { seen[key] = .some(nil) } else { seen[key] = .some(url) }
        }
        for (key, value) in seen { if let url = value { index.byName[key] = url } }
        return index
    }
}

enum LogoCatalog {
    private static let sourceURL = URL(string: "https://iptv-org.github.io/api/logos.json")!
    private static let maxAge: TimeInterval = 7 * 24 * 3600
    private static let rasterFormats: Set<String> = ["PNG", "JPG", "JPEG", "WEBP"]

    private static var cacheURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("logo_catalog.tsv")
    }

    /// Returns the cached index at once (if any) through `onUpdate`, then refreshes it when stale.
    static func load(onUpdate: @escaping (LogoIndex) -> Void) async {
        let cache = cacheURL
        let attributes = try? FileManager.default.attributesOfItem(atPath: cache.path)
        let modified = attributes?[.modificationDate] as? Date
        if let text = try? String(contentsOf: cache, encoding: .utf8) {
            var entries: [String: String] = [:]
            for line in text.split(separator: "\n") {
                guard let tab = line.firstIndex(of: "\t") else { continue }
                entries[String(line[..<tab])] = String(line[line.index(after: tab)...])
            }
            onUpdate(LogoIndex.make(from: entries))
        }
        if let modified, Date().timeIntervalSince(modified) < maxAge { return }

        guard let (data, response) = try? await URLSession.shared.data(from: sourceURL),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }
        var entries: [String: String] = [:]
        for row in rows {
            guard let channel = row["channel"] as? String,
                  let url = row["url"] as? String, url.hasPrefix("https://"),
                  let format = row["format"] as? String, rasterFormats.contains(format.uppercased()) else { continue }
            let key = channel.lowercased()
            if entries[key] == nil { entries[key] = url }
        }
        let body = entries.map { "\($0.key)\t\($0.value)" }.joined(separator: "\n")
        try? body.write(to: cache, atomically: true, encoding: .utf8)
        onUpdate(LogoIndex.make(from: entries))
    }
}
