import SwiftUI
import Combine

/// The app's single source of truth: playlist channels, radio stations, favorites, deletions and the
/// user's settings. Heavy work (parsing a ~8 MB playlist, building bouquets) runs off the main
/// thread; the published values are only ever replaced as a whole.
final class AppStore: ObservableObject {
    static let builtInPlaylistURL = "https://iptv-org.github.io/iptv/index.m3u"

    // Channels
    @Published private(set) var channels: [Channel] = []
    @Published private(set) var bouquets: [Bouquet] = []
    @Published private(set) var specialties: [String] = []
    @Published private(set) var isLoading = false

    // Radio
    @Published private(set) var stations: [RadioStation] = []

    // User data
    @Published var favorites: Set<String> { didSet { defaults.set(Array(favorites), forKey: "favorites") } }
    @Published var deleted: Set<String> {
        didSet {
            defaults.set(Array(deleted), forKey: "deleted")
            rebuild()
        }
    }
    @Published var extraPlaylists: [String] { didSet { defaults.set(extraPlaylists, forKey: "extraPlaylists") } }
    @Published var languageCode: String { didSet { defaults.set(languageCode, forKey: "language") } }
    @Published var backgroundVersion = 0

    private let defaults = UserDefaults.standard
    private var raw: [Channel] = []
    private var logoIndex: LogoIndex?
    private var started = false

    init() {
        favorites = Set(defaults.stringArray(forKey: "favorites") ?? [])
        deleted = Set(defaults.stringArray(forKey: "deleted") ?? [])
        extraPlaylists = defaults.stringArray(forKey: "extraPlaylists") ?? []
        languageCode = defaults.string(forKey: "language") ?? "system"
        stations = AppStore.loadStations()
    }

    // MARK: Language

    var locale: Locale {
        languageCode == "system" ? Locale.autoupdatingCurrent : Locale(identifier: languageCode)
    }

    var layoutDirection: LayoutDirection {
        let code = languageCode == "system" ? (Locale.autoupdatingCurrent.language.languageCode?.identifier ?? "en") : languageCode
        return code == "ar" ? .rightToLeft : .leftToRight
    }

    // MARK: Loading

    func start() {
        guard !started else { return }
        started = true
        Task { await loadChannels(force: false) }
        Task {
            await LogoCatalog.load { [weak self] index in
                DispatchQueue.main.async {
                    self?.logoIndex = index
                    self?.rebuild()
                }
            }
        }
    }

    func refresh() {
        Task { await loadChannels(force: true) }
    }

    private var cacheURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("channels.json")
    }

    @MainActor
    private func loadChannels(force: Bool) async {
        let cache = cacheURL
        if raw.isEmpty, let data = try? Data(contentsOf: cache),
           let cached = try? JSONDecoder().decode([Channel].self, from: data) {
            raw = cached
            rebuild()
        }
        let modified = (try? FileManager.default.attributesOfItem(atPath: cache.path))?[.modificationDate] as? Date
        let fresh = modified.map { Date().timeIntervalSince($0) < 12 * 3600 } ?? false
        if fresh && !force && !raw.isEmpty { return }

        isLoading = true
        let urls = [AppStore.builtInPlaylistURL] + extraPlaylists
        let parsed: [Channel] = await Task.detached(priority: .userInitiated) { () -> [Channel] in
            var all: [Channel] = []
            var seen = Set<String>()
            for urlString in urls {
                guard let url = URL(string: urlString),
                      let (data, response) = try? await URLSession.shared.data(from: url),
                      (response as? HTTPURLResponse)?.statusCode == 200,
                      let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
                else { continue }
                for channel in M3UParser.parse(text) where seen.insert(channel.url).inserted {
                    all.append(channel)
                }
            }
            return all
        }.value
        isLoading = false

        // A failed refresh keeps what is cached; an empty result is never treated as "no channels".
        guard !parsed.isEmpty else { return }
        raw = parsed
        if let data = try? JSONEncoder().encode(parsed) { try? data.write(to: cache, options: .atomic) }
        rebuild()
    }

    /// Hides deleted / foreign / Israeli channels, completes missing logos, and recomputes groups.
    private func rebuild() {
        let snapshot = raw
        let hidden = deleted
        let index = logoIndex
        Task.detached(priority: .userInitiated) { [weak self] in
            let visible = snapshot
                .filter { !hidden.contains($0.id) && $0.isShown }
                .map { index?.apply(to: $0) ?? $0 }
            let groups = makeBouquets(visible)
            let labels = makeSpecialties(visible)
            await MainActor.run {
                self?.channels = visible
                self?.bouquets = groups
                self?.specialties = labels
            }
        }
    }

    // MARK: Radio

    private static func loadStations() -> [RadioStation] {
        guard let url = Bundle.main.url(forResource: "radio_stations", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([RadioStation].self, from: data) else { return [] }
        return list.filter { $0.url.hasPrefix("https://") }
    }

    var radioBouquets: [Bouquet] {
        var counts: [String: Int] = [:]
        for station in stations { counts[station.country?.uppercased() ?? Bouquet.otherKey, default: 0] += 1 }
        return counts
            .map { Bouquet(key: $0.key, count: $0.value) }
            .sorted { a, b in
                if (a.key == Bouquet.otherKey) != (b.key == Bouquet.otherKey) { return b.key == Bouquet.otherKey }
                return a.count > b.count
            }
    }

    // MARK: Favorites & deletion

    func isFavorite(_ key: String) -> Bool { favorites.contains(key) }

    func toggleFavorite(_ key: String) {
        if favorites.contains(key) { favorites.remove(key) } else { favorites.insert(key) }
    }

    func delete(_ channel: Channel) {
        favorites.remove(channel.id)
        deleted.insert(channel.id)
    }

    // MARK: Background picture

    static var backgroundFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("background.jpg")
    }

    func setBackground(data: Data?) {
        if let data, let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.85) {
            try? jpeg.write(to: AppStore.backgroundFileURL, options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: AppStore.backgroundFileURL)
        }
        backgroundVersion += 1
    }
}
