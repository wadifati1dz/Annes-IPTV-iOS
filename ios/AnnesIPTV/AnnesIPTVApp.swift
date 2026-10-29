import SwiftUI

@main
struct AnnesIPTVApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var radio = RadioPlayer.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(radio)
                .environment(\.locale, store.locale)
                .environment(\.layoutDirection, store.layoutDirection)
                .preferredColorScheme(.dark)
                .tint(Theme.gold)
                .task { store.start() }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var radio: RadioPlayer

    var body: some View {
        NavigationStack {
            HomeView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .liveTV(let topic): LiveTVView(topic: topic)
                    case .radio: RadioView()
                    case .favorites: FavoritesView()
                    case .settings: SettingsView()
                    }
                }
        }
        .safeAreaInset(edge: .bottom) {
            if radio.isActive && !radio.showFullScreen {
                RadioMiniPlayer()
            }
        }
        .fullScreenCover(isPresented: $radio.showFullScreen) {
            RadioNowPlayingView()
        }
    }
}
