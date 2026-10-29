import Foundation

/// Country, language, topic and bouquet rules, ported from the Android app so both apps group and
/// hide channels the same way.
enum ChannelLanguage { case arabic, french, english, other }

private let isoCountries: Set<String> = Set(Locale.isoRegionCodes)

private let countryByEnglishName: [String: String] = {
    let english = Locale(identifier: "en")
    var map: [String: String] = [:]
    for code in Locale.isoRegionCodes {
        if let name = english.localizedString(forRegionCode: code) { map[name.lowercased()] = code }
    }
    return map
}()

private let arabCountries: Set<String> = [
    "DZ", "MA", "TN", "LY", "EG", "SD", "MR", "SA", "AE", "QA", "KW", "BH",
    "OM", "YE", "IQ", "SY", "JO", "LB", "PS", "SO", "DJ", "KM"
]
private let frenchCountries: Set<String> = ["FR", "BE", "CH", "LU", "MC"]
private let englishCountries: Set<String> = ["US", "GB", "IE", "AU", "NZ", "CA", "ZA"]
private let notCountrySuffixes: Set<String> = ["tv", "fm", "am", "cc", "ws"]
private let genericGroups: Set<String> = [
    "general", "news", "undefined", "uncategorized", "unknown", "other", "others", "misc", "default"
]
private let israelMarkers = ["israel", "isreal", "إسرائيل", "اسرائيل", "israël"]

private let nameLanguageMarkers: [String: ChannelLanguage] = {
    var map: [String: ChannelLanguage] = ["arabic": .arabic, "arabe": .arabic]
    for word in ["french", "francais", "français"] { map[word] = .french }
    for word in ["english", "anglais"] { map[word] = .english }
    for word in [
        "urdu", "bangla", "bengali", "chinese", "persian", "farsi", "kurdish", "kurdi", "turkish",
        "hindi", "indonesia", "indonesian", "malay", "spanish", "espanol", "portuguese", "russian",
        "german", "italian", "tamil", "telugu", "pashto", "swahili", "amharic", "korean", "japanese",
        "thai", "vietnamese", "greek", "hebrew"
    ] { map[word] = .other }
    return map
}()

private let christianMarkers = [
    "aghapy", "agapy", "coptic", "abnsat", "abn sat", "noursat", "nour mariam", "koddass",
    "nour al sharq", "nour el shabeb", "mariam", "koogi", "ishtar", "christ", "church", "bible",
    "catholic", "orthodox", "sat-7", "sat7", "sat 7", "miracle", "logos",
    "مسيح", "قبط", "كنيس", "الكتاب المقدس", "نور سات", "نور مريم", "قديس", "مريم"
]

/// "SA", "sa", "uk" and "Saudi Arabia" all resolve; anything else is nil.
func resolveCountryCode(_ raw: String?) -> String? {
    let value = (raw ?? "").trimmingCharacters(in: .whitespaces)
    if value.isEmpty { return nil }
    if value.count == 2, value.allSatisfy({ $0.isLetter }) {
        var code = value.uppercased()
        if code == "UK" { code = "GB" }
        return isoCountries.contains(code) ? code : nil
    }
    return countryByEnglishName[value.lowercased()]
}

func countryFlag(_ code: String) -> String {
    code.uppercased().unicodeScalars.compactMap { scalar -> String? in
        guard let flag = UnicodeScalar(0x1F1E6 + scalar.value - 65) else { return nil }
        return String(flag)
    }.joined()
}

func countryName(_ code: String, locale: Locale) -> String {
    locale.localizedString(forRegionCode: code) ?? code
}

extension Channel {
    private var tvgIdCountryCode: String? {
        let id = (tvgId ?? "").split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? ""
        guard let dot = id.lastIndex(of: ".") else { return nil }
        let suffix = String(id[id.index(after: dot)...]).lowercased()
        if suffix.count != 2 || notCountrySuffixes.contains(suffix) { return nil }
        return resolveCountryCode(suffix)
    }

    /// ISO codes: `tvg-country` values (codes or names, possibly "FR;SA"), else the tvg-id suffix.
    var countryCodes: [String] {
        let separators = CharacterSet(charactersIn: ";,|/")
        let fromAttribute = (country ?? "")
            .components(separatedBy: separators)
            .compactMap { resolveCountryCode($0) }
        var unique: [String] = []
        for code in fromAttribute where !unique.contains(code) { unique.append(code) }
        if !unique.isEmpty { return unique }
        return tvgIdCountryCode.map { [$0] } ?? []
    }

    var detectedLanguage: ChannelLanguage? {
        if let fromAttribute = languageFromAttribute { return fromAttribute }
        for token in name.lowercased().split(whereSeparator: { !$0.isLetter }) {
            if let marker = nameLanguageMarkers[String(token)] { return marker }
        }
        if name.unicodeScalars.contains(where: { (0x0600...0x06FF).contains($0.value) }) { return .arabic }
        if name.unicodeScalars.contains(where: { CharacterSet.letters.contains($0) && !isLatinLike($0) }) {
            return .other
        }
        let groupText = (group ?? "").lowercased()
        if groupText.contains("arab") || groupText.contains("عرب") { return .arabic }
        let codes = countryCodes
        if codes.isEmpty { return nil }
        if codes.contains(where: { arabCountries.contains($0) }) { return .arabic }
        if codes.contains(where: { frenchCountries.contains($0) }) { return .french }
        if codes.contains(where: { englishCountries.contains($0) }) { return .english }
        return .other
    }

    private var languageFromAttribute: ChannelLanguage? {
        let tokens = (language ?? "").lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init)
        if tokens.isEmpty { return nil }
        let found = tokens.map { languageFromToken($0) ?? .other }
        if found.contains(where: { if case .arabic = $0 { return true } else { return false } }) { return .arabic }
        if found.contains(where: { if case .french = $0 { return true } else { return false } }) { return .french }
        if found.contains(where: { if case .english = $0 { return true } else { return false } }) { return .english }
        return .other
    }

    var isArabic: Bool {
        if case .arabic? = detectedLanguage { return true }
        return false
    }

    var isIsraeli: Bool {
        if countryCodes.contains("IL") { return true }
        let texts = [name, group ?? "", country ?? ""].map { $0.lowercased() }
        return texts.contains { text in israelMarkers.contains { text.contains($0) } }
    }

    /// Foreign-language and Israeli channels are hidden everywhere.
    var isShown: Bool {
        if case .other? = detectedLanguage { return false }
        return !isIsraeli
    }

    /// The channel's bouquet: its country, else its group label, else the catch-all.
    var bouquetKey: String {
        if let code = countryCodes.first { return code }
        if let code = resolveCountryCode(group) { return code }
        if let label = group?.trimmingCharacters(in: .whitespaces),
           !label.isEmpty, !genericGroups.contains(label.lowercased()) {
            return label
        }
        return Bouquet.otherKey
    }

    func matches(topic: String?) -> Bool {
        guard let topic else { return true }
        let haystack = "\(group ?? "") \(name)".lowercased()
        switch topic {
        case "news":
            let keys = ["news", "info", "infos", "actualit", "journal",
                        "أخبار", "اخبار", "الإخبارية", "الاخبارية", "إخبارية", "اخبارية", "نشرة"]
            return keys.contains { haystack.contains($0) }
        case "religious":
            let keys = ["quran", "koran", "coran", "islam", "religio", "sunna", "sunnah", "makkah", "mecca",
                        "madina", "iqra", "islamic", "azhar", "azhari", "majd", "resalah", "risalah", "hidaya",
                        "قرآن", "قران", "القرآن", "إسلام", "اسلام", "ديني", "دينية", "الدينية", "مكة", "المدينة",
                        "السنة", "اقرأ", "اقرا", "الأزهر", "الازهر", "المجد", "الرسالة", "هداية"]
            guard keys.contains(where: { haystack.contains($0) }) else { return false }
            if christianMarkers.contains(where: { haystack.contains($0) }) { return false }
            return isArabic
        default:
            return true
        }
    }
}

private func languageFromToken(_ token: String) -> ChannelLanguage? {
    switch token {
    case "ar", "ara", "arabic", "arabe", "عربي", "العربية": return .arabic
    case "fr", "fra", "fre", "french", "francais", "français": return .french
    case "en", "eng", "english", "anglais": return .english
    default: return nil
    }
}

private func isLatinLike(_ scalar: UnicodeScalar) -> Bool {
    // Latin letters (with accents) and Arabic script count as readable for this app's audience.
    let v = scalar.value
    return v < 0x0250 || (0x1E00...0x1EFF).contains(v) || (0x0600...0x06FF).contains(v)
}

/// Bouquets present in a channel list: largest first, the catch-all last.
func makeBouquets(_ channels: [Channel]) -> [Bouquet] {
    var counts: [String: Int] = [:]
    for channel in channels { counts[channel.bouquetKey, default: 0] += 1 }
    return counts
        .map { Bouquet(key: $0.key, count: $0.value) }
        .sorted { a, b in
            if (a.key == Bouquet.otherKey) != (b.key == Bouquet.otherKey) { return b.key == Bouquet.otherKey }
            return a.count > b.count
        }
}

func bouquetDisplayName(_ key: String, locale: Locale, otherLabel: String) -> String {
    if key.isEmpty { return otherLabel }
    if resolveCountryCode(key) != nil { return countryName(key, locale: locale) }
    return key
}

/// Distinct group labels (the "specialties"), sorted, without catch-all names.
func makeSpecialties(_ channels: [Channel]) -> [String] {
    var seen = Set<String>()
    var result: [String] = []
    for channel in channels {
        guard let label = channel.group?.trimmingCharacters(in: .whitespaces), !label.isEmpty else { continue }
        if seen.insert(label.lowercased()).inserted { result.append(label) }
    }
    return result.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
}
