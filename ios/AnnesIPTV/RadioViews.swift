import SwiftUI

private func genreKey(_ genre: String) -> LocalizedStringKey { LocalizedStringKey("genre_" + genre) }

/// Radio: bouquets by country first, then the stations of the chosen one. Same look as Live TV.
struct RadioView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var radio: RadioPlayer
    @Environment(\.locale) private var locale

    @State private var query = ""
    @State private var bouquet: String?
    @State private var genre: String?
    @State private var favoritesOnly = false

    private var otherLabel: String {
        NSLocalizedString("other", bundle: bundle(for: locale), comment: "")
    }

    private var genres: [String] {
        Array(Set(store.stations.map { $0.genre })).sorted()
    }

    private var showBouquets: Bool {
        bouquet == nil && query.isEmpty && genre == nil && !favoritesOnly
    }

    private var filtered: [RadioStation] {
        store.stations.filter { station in
            if let bouquet, (station.country?.uppercased() ?? Bouquet.otherKey) != bouquet { return false }
            if let genre, station.genre != genre { return false }
            if favoritesOnly, !store.isFavorite(station.favoriteKey) { return false }
            if !query.isEmpty, !station.name.localizedCaseInsensitiveContains(query) { return false }
            return true
        }
    }

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: landscape ? 8 : 3)
            ScrollView {
                VStack(spacing: 12) {
                    searchRow
                    if showBouquets {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(store.radioBouquets) { item in
                                BouquetCell(
                                    bouquet: item,
                                    name: bouquetDisplayName(item.key, locale: locale, otherLabel: otherLabel),
                                    unit: "stations_word"
                                ) { bouquet = item.key }
                            }
                        }
                    } else {
                        if let bouquet {
                            BouquetHeader(
                                name: bouquetDisplayName(bouquet, locale: locale, otherLabel: otherLabel),
                                onBack: { self.bouquet = nil }
                            )
                        }
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(filtered) { station in
                                StationCell(
                                    station: station,
                                    isCurrent: radio.station?.id == station.id
                                )
                                .onTapGesture {
                                    radio.play(station, queue: filtered)
                                    radio.showFullScreen = true
                                }
                                .contextMenu {
                                    Button {
                                        store.toggleFavorite(station.favoriteKey)
                                    } label: {
                                        Label(
                                            LocalizedStringKey(store.isFavorite(station.favoriteKey) ? "favorites_remove" : "favorites_add"),
                                            systemImage: store.isFavorite(station.favoriteKey) ? "heart.slash" : "heart"
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
        .appBackground()
        .navigationTitle(Text("nav_radio"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var searchRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField(LocalizedStringKey("radio_search_hint"), text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 46)
            .glassCard(cornerRadius: 23)

            Button { favoritesOnly.toggle() } label: {
                Image(systemName: favoritesOnly ? "heart.fill" : "heart")
                    .foregroundColor(favoritesOnly ? Theme.gold : .secondary)
                    .frame(width: 46, height: 46)
                    .glassCard(cornerRadius: 23)
            }

            Menu {
                Button("all") { genre = nil }
                ForEach(genres, id: \.self) { item in
                    Button {
                        genre = item
                    } label: {
                        if genre == item {
                            Label { Text(genreKey(item)) } icon: { Image(systemName: "checkmark") }
                        } else {
                            Text(genreKey(item))
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.grid.2x2")
                    if let genre { Text(genreKey(genre)).lineLimit(1) } else { Text("genre") }
                    Image(systemName: "chevron.down").font(.caption2)
                }
                .font(.subheadline.weight(genre == nil ? .regular : .semibold))
                .foregroundColor(genre == nil ? .secondary : Theme.gold)
                .padding(.horizontal, 12)
                .frame(height: 46)
                .glassCard(cornerRadius: 23)
            }
        }
    }
}

struct StationCell: View {
    let station: RadioStation
    let isCurrent: Bool

    var body: some View {
        VStack(spacing: 6) {
            LogoView(url: station.logo, name: station.name)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(station.name)
                .font(.caption2)
                .foregroundColor(isCurrent ? Theme.gold : .primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: 28, alignment: .top)
        }
        .padding(8)
        .glassCard()
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isCurrent ? Theme.gold : .clear, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Mini player

/// The mini player: a dark gold-edged card with the round artwork, the name and status, a live
/// equalizer, and the transport controls. Tapping it opens the full player.
struct RadioMiniPlayer: View {
    @EnvironmentObject private var radio: RadioPlayer

    var body: some View {
        if let station = radio.station {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    LogoView(url: station.logo, name: station.name)
                        .frame(width: 52, height: 52)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Theme.gold.opacity(radio.state == .playing ? 0.9 : 0.45), lineWidth: 2))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(station.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                        HStack(spacing: 8) {
                            if radio.state != .failed { Equalizer(active: radio.state == .playing) }
                            RadioStatusText(state: radio.state).font(.caption)
                        }
                    }
                    Spacer()
                    Button { radio.stop() } label: {
                        Image(systemName: "stop.fill")
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.08), in: Circle())
                    }
                }
                HStack(spacing: 22) {
                    Spacer()
                    transport("backward.fill", enabled: radio.hasPrevious) { radio.previous() }
                    Button { radio.togglePlayPause() } label: {
                        Image(systemName: playSymbol)
                            .font(.title2.weight(.bold))
                            .foregroundColor(Color(red: 0.1, green: 0.075, blue: 0.02))
                            .frame(width: 54, height: 54)
                            .background(Theme.gold, in: Circle())
                    }
                    transport("forward.fill", enabled: radio.hasNext) { radio.next() }
                    Spacer()
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(Theme.capsule, in: RoundedCornerShape(26))
            .overlay(RoundedCornerShape(26).stroke(Theme.gold.opacity(0.6), lineWidth: 1))
            .shadow(color: .black.opacity(0.5), radius: 10, y: 4)
            .padding(.horizontal, 12).padding(.bottom, 6)
            .contentShape(Rectangle())
            .onTapGesture { radio.showFullScreen = true }
        }
    }

    private var playSymbol: String {
        switch radio.state {
        case .failed: return "arrow.clockwise"
        case .paused: return "play.fill"
        default: return "pause.fill"
        }
    }

    private func transport(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.title3)
                .frame(width: 46, height: 46)
                .opacity(enabled ? 1 : 0.35)
        }
        .disabled(!enabled)
    }
}

struct RoundedCornerShape: Shape {
    var radius: CGFloat
    init(_ radius: CGFloat) { self.radius = radius }
    func path(in rect: CGRect) -> Path {
        RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: rect)
    }
}

struct RadioStatusText: View {
    let state: RadioPlayer.State

    var body: some View {
        switch state {
        case .connecting: Text("status_connecting").foregroundColor(.white.opacity(0.7))
        case .playing: Text("status_playing").foregroundColor(Theme.gold)
        case .paused: Text("status_paused").foregroundColor(.white.opacity(0.7))
        case .failed: Text("status_error").foregroundColor(.red)
        case .idle: Text("")
        }
    }
}

// MARK: - Full-screen player

/// The full-screen radio player: round artwork in a gold ring, the name, a country + genre pill, the
/// status, and one capsule row — favorite, previous, play, next, stop.
struct RadioNowPlayingView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var radio: RadioPlayer
    @Environment(\.locale) private var locale

    @State private var showList = false
    @State private var panelBouquet: String?

    private var otherLabel: String {
        NSLocalizedString("other", bundle: bundle(for: locale), comment: "")
    }

    var body: some View {
        ZStack {
            AppBackground()
            if let station = radio.station {
                VStack {
                    HStack {
                        roundButton("chevron.down") { radio.showFullScreen = false }
                        Spacer()
                        roundButton("list.bullet") {
                            panelBouquet = station.country?.uppercased()
                            showList = true
                        }
                    }
                    Spacer()
                    artwork(station)
                    Text(station.name)
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.top, 20)
                    subtitle(station)
                    HStack(spacing: 10) {
                        if radio.state != .failed { Equalizer(active: radio.state == .playing) }
                        RadioStatusText(state: radio.state).font(.subheadline)
                    }
                    .padding(.top, 12)
                    Spacer()
                    controls(station)
                        .padding(.bottom, 12)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
        }
        .sheet(isPresented: $showList) { stationSheet }
    }

    private func roundButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.headline)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.1), in: Circle())
        }
    }

    private func artwork(_ station: RadioStation) -> some View {
        LogoView(url: station.logo, name: station.name)
            .frame(width: 230, height: 230)
            .clipShape(Circle())
            .padding(8)
            .overlay(Circle().stroke(Theme.gold.opacity(radio.state == .playing ? 0.9 : 0.5), lineWidth: 3))
            .shadow(color: Theme.gold.opacity(0.4), radius: 28)
    }

    private func subtitle(_ station: RadioStation) -> some View {
        let flag = station.country.flatMap { resolveCountryCode($0) }.map(countryFlag)
        return HStack(spacing: 6) {
            if let flag { Text(flag) }
            if let code = station.country { Text(countryName(code, locale: locale)) }
            Text("·")
            Text(genreKey(station.genre))
        }
        .font(.footnote)
        .foregroundColor(.white.opacity(0.8))
        .padding(.horizontal, 14).padding(.vertical, 5)
        .background(Color.white.opacity(0.08), in: Capsule())
        .padding(.top, 8)
    }

    private func controls(_ station: RadioStation) -> some View {
        HStack(spacing: 6) {
            Button { store.toggleFavorite(station.favoriteKey) } label: {
                Image(systemName: store.isFavorite(station.favoriteKey) ? "heart.fill" : "heart")
                    .foregroundColor(store.isFavorite(station.favoriteKey) ? Theme.gold : .white)
                    .frame(width: 46, height: 46)
            }
            button("backward.fill", size: 52, enabled: radio.hasPrevious) { radio.previous() }
            Button { radio.togglePlayPause() } label: {
                Image(systemName: radio.state == .failed ? "arrow.clockwise" : (radio.state == .paused ? "play.fill" : "pause.fill"))
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(Color(red: 0.1, green: 0.075, blue: 0.02))
                    .frame(width: 70, height: 70)
                    .background(Theme.gold, in: Circle())
            }
            button("forward.fill", size: 52, enabled: radio.hasNext) { radio.next() }
            Button { radio.stop() } label: {
                Image(systemName: "stop.fill").frame(width: 46, height: 46)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(Theme.capsule, in: Capsule())
        .overlay(Capsule().stroke(Theme.gold.opacity(0.55), lineWidth: 1))
    }

    private func button(_ symbol: String, size: CGFloat, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.title3)
                .frame(width: size, height: size)
                .opacity(enabled ? 1 : 0.35)
        }
        .disabled(!enabled)
    }

    // The side list as a sheet: crest, bouquet drop-down, round logos with names.
    private var stationSheet: some View {
        let shown = panelBouquet == nil
            ? store.stations
            : store.stations.filter { ($0.country?.uppercased() ?? Bouquet.otherKey) == panelBouquet }
        return VStack(spacing: 10) {
            Image("AppLogo").resizable().scaledToFit().frame(height: 46).padding(.top, 14)
            Menu {
                Button("all") { panelBouquet = nil }
                ForEach(store.radioBouquets) { item in
                    Button {
                        panelBouquet = item.key
                    } label: {
                        Text(
                            (resolveCountryCode(item.key) != nil ? countryFlag(item.key) + " " : "")
                            + bouquetDisplayName(item.key, locale: locale, otherLabel: otherLabel)
                            + "  ·  \(item.count)"
                        )
                    }
                }
            } label: {
                HStack {
                    Text(panelBouquet.map { bouquetDisplayName($0, locale: locale, otherLabel: otherLabel) }
                         ?? NSLocalizedString("all", bundle: bundle(for: locale), comment: ""))
                        .font(.subheadline.weight(.semibold)).lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.down").foregroundColor(Theme.gold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14).frame(height: 44)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.gold.opacity(0.6), lineWidth: 1))
            }
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(shown) { station in
                        let isCurrent = station.id == radio.station?.id
                        HStack(spacing: 12) {
                            LogoView(url: station.logo, name: station.name)
                                .frame(width: 42, height: 42).clipShape(Circle())
                            Text(station.name)
                                .font(.subheadline.weight(isCurrent ? .semibold : .regular))
                                .foregroundColor(isCurrent ? Theme.gold : .white)
                                .lineLimit(2)
                            Spacer()
                        }
                        .padding(.leading, 6).padding(.trailing, 14).padding(.vertical, 6)
                        .background(isCurrent ? Theme.gold.opacity(0.18) : Color.white.opacity(0.05), in: Capsule())
                        .overlay(Capsule().stroke(isCurrent ? Theme.gold.opacity(0.7) : .clear, lineWidth: 1))
                        .contentShape(Capsule())
                        .onTapGesture {
                            radio.play(station, queue: shown)
                            showList = false
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .background(Theme.capsule.ignoresSafeArea())
        .presentationDetents([.large])
    }
}
