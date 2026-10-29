import SwiftUI

/// Live TV: bouquets (country / group) first, then the channels of the chosen one. Tap plays; a long
/// press offers favorite / delete. The search pill and the specialty menu share one row.
struct LiveTVView: View {
    let topic: String?

    @EnvironmentObject private var store: AppStore
    @Environment(\.locale) private var locale

    @State private var query = ""
    @State private var category: String?
    @State private var bouquet: String?
    @State private var playing: PlayRequest?

    struct PlayRequest: Identifiable {
        let channel: Channel
        let list: [Channel]
        var id: String { channel.id }
    }

    private var titleKey: LocalizedStringKey {
        switch topic {
        case "news": return "nav_news"
        case "religious": return "nav_religious"
        default: return "nav_live_tv"
        }
    }

    private var base: [Channel] {
        topic == nil ? store.channels : store.channels.filter { $0.matches(topic: topic) }
    }

    private var bouquets: [Bouquet] { topic == nil ? store.bouquets : makeBouquets(base) }
    private var specialties: [String] { topic == nil ? store.specialties : makeSpecialties(base) }

    private var showBouquets: Bool { bouquet == nil && query.isEmpty && category == nil }

    private var filtered: [Channel] {
        base.filter { channel in
            if let bouquet, channel.bouquetKey != bouquet { return false }
            if let category, channel.group?.caseInsensitiveCompare(category) != .orderedSame { return false }
            if !query.isEmpty, !channel.name.localizedCaseInsensitiveContains(query) { return false }
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
                    if base.isEmpty {
                        emptyState
                    } else if showBouquets {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(bouquets) { item in
                                BouquetCell(
                                    bouquet: item,
                                    name: bouquetDisplayName(item.key, locale: locale, otherLabel: otherLabel),
                                    unit: "channels_word"
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
                        HStack(spacing: 4) {
                            Text("\(filtered.count)")
                            Text("channels_word")
                            Spacer()
                        }
                        .font(.footnote).foregroundColor(.secondary)
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(filtered) { channel in
                                ChannelCell(channel: channel, isFavorite: store.isFavorite(channel.id))
                                    .onTapGesture { playing = PlayRequest(channel: channel, list: filtered) }
                                    .contextMenu {
                                        Button {
                                            store.toggleFavorite(channel.id)
                                        } label: {
                                            Label(
                                                LocalizedStringKey(store.isFavorite(channel.id) ? "favorites_remove" : "favorites_add"),
                                                systemImage: store.isFavorite(channel.id) ? "heart.slash" : "heart"
                                            )
                                        }
                                        Button(role: .destructive) {
                                            store.delete(channel)
                                        } label: {
                                            Label("delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .refreshable { store.refresh() }
        }
        .appBackground()
        .onAppear {
            // Screenshot hook (see RootView): open a bouquet straight away.
            if bouquet == nil, let key = UserDefaults.standard.string(forKey: "startBouquet") { bouquet = key }
        }
        .navigationTitle(Text(titleKey))
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $playing) { request in
            ChannelPlayerView(channel: request.channel, list: request.list)
        }
    }

    private var otherLabel: String {
        NSLocalizedString("other", bundle: bundle(for: locale), comment: "")
    }

    private var searchRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField(LocalizedStringKey("search_hint"), text: $query)
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

            if !specialties.isEmpty {
                Menu {
                    Button("all") { category = nil }
                    ForEach(specialties, id: \.self) { label in
                        Button {
                            category = label
                        } label: {
                            if category?.caseInsensitiveCompare(label) == .orderedSame {
                                Label(label, systemImage: "checkmark")
                            } else {
                                Text(label)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.grid.2x2")
                        if let category {
                            Text(category).lineLimit(1)
                        } else {
                            Text("category")
                        }
                        Image(systemName: "chevron.down").font(.caption2)
                    }
                    .font(.subheadline.weight(category == nil ? .regular : .semibold))
                    .foregroundColor(category == nil ? .secondary : Theme.gold)
                    .padding(.horizontal, 14)
                    .frame(height: 46)
                    .frame(maxWidth: 160)
                    .glassCard(cornerRadius: 23)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            if store.isLoading {
                ProgressView()
                Text("loading").foregroundColor(.secondary)
            } else {
                Image(systemName: "tv").font(.largeTitle).foregroundColor(Theme.gold)
                Text("empty_title").font(.headline)
                Text("empty_message").font(.footnote).foregroundColor(.secondary).multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

/// One tile of the grid: the logo on a plate with the name (two lines) under it.
struct ChannelCell: View {
    let channel: Channel
    let isFavorite: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                LogoView(url: channel.logo, name: channel.name)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                if isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.gold)
                        .padding(5)
                        .background(Color.black.opacity(0.6), in: Circle())
                        .padding(4)
                }
            }
            Text(channel.name)
                .font(.caption2)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: 28, alignment: .top)
        }
        .padding(8)
        .glassCard()
        .contentShape(Rectangle())
    }
}

/// The bundle for the app's chosen language, so non-`Text` strings follow the in-app language.
func bundle(for locale: Locale) -> Bundle {
    let code = locale.language.languageCode?.identifier ?? "en"
    if let path = Bundle.main.path(forResource: code, ofType: "lproj"), let bundle = Bundle(path: path) {
        return bundle
    }
    return .main
}
