import SwiftUI

/// Favorite channels and stations in one place.
struct FavoritesView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var radio: RadioPlayer

    @State private var playing: LiveTVView.PlayRequest?

    private var channels: [Channel] { store.channels.filter { store.isFavorite($0.id) } }
    private var stations: [RadioStation] { store.stations.filter { store.isFavorite($0.favoriteKey) } }

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: landscape ? 8 : 3)
            ScrollView {
                if channels.isEmpty && stations.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "heart").font(.largeTitle).foregroundColor(Theme.gold)
                        Text("favorites_empty").foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        if !channels.isEmpty {
                            Text("nav_live_tv").font(.headline)
                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(channels) { channel in
                                    ChannelCell(channel: channel, isFavorite: true)
                                        .onTapGesture { playing = .init(channel: channel, list: channels) }
                                        .contextMenu {
                                            Button { store.toggleFavorite(channel.id) } label: {
                                                Label("favorites_remove", systemImage: "heart.slash")
                                            }
                                        }
                                }
                            }
                        }
                        if !stations.isEmpty {
                            Text("nav_radio").font(.headline).padding(.top, 6)
                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(stations) { station in
                                    StationCell(station: station, isCurrent: radio.station?.id == station.id)
                                        .onTapGesture {
                                            radio.play(station, queue: stations)
                                            radio.showFullScreen = true
                                        }
                                        .contextMenu {
                                            Button { store.toggleFavorite(station.favoriteKey) } label: {
                                                Label("favorites_remove", systemImage: "heart.slash")
                                            }
                                        }
                                }
                            }
                        }
                    }
                    .padding(12)
                }
            }
        }
        .appBackground()
        .navigationTitle(Text("nav_favorites"))
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $playing) { request in
            ChannelPlayerView(channel: request.channel, list: request.list)
        }
    }
}
