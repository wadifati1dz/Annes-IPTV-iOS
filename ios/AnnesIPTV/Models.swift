import Foundation

/// A live TV channel read from an M3U playlist.
struct Channel: Identifiable, Hashable, Codable {
    /// The stream URL is the identity: favorites and deletions survive a playlist refresh.
    var id: String { url }
    let name: String
    let url: String
    var logo: String?
    let tvgId: String?
    let country: String?
    let language: String?
    let group: String?
}

/// A bundled radio station (verified stream, see tools/radio in the repository).
struct RadioStation: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let country: String?
    let language: String?
    let genre: String
    let url: String
    let logo: String?

    var favoriteKey: String { "radio:" + id }
}

/// A group of channels or stations: an ISO country code, a group label, or `otherKey`.
struct Bouquet: Identifiable, Hashable {
    let key: String
    let count: Int
    var id: String { key }

    static let otherKey = ""
}

enum ChannelTopic {
    case news, religious
}

enum Route: Hashable {
    case liveTV(topic: String?)   // nil = all channels, "news", "religious"
    case radio
    case favorites
    case settings
}
