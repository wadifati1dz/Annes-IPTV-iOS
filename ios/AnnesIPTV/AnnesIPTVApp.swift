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
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var radio: RadioPlayer
    @State private var path = NavigationPath()
    @State private var openedFromArguments = false

    var body: some View {
        NavigationStack(path: $path) {
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
        .task { openFromArguments() }
    }

    /// `-startRoute live|news|religious|radio|favorites|settings` opens that screen at launch and
    /// `-startRadioFull 1` opens the full-screen radio player. They exist so the cloud build can
    /// take screenshots of each screen; normal launches pass none of them.
    private func openFromArguments() {
        guard !openedFromArguments else { return }
        openedFromArguments = true
        let defaults = UserDefaults.standard
        switch defaults.string(forKey: "startRoute") {
        case "live": path.append(Route.liveTV(topic: nil))
        case "news": path.append(Route.liveTV(topic: "news"))
        case "religious": path.append(Route.liveTV(topic: "religious"))
        case "radio": path.append(Route.radio)
        case "favorites": path.append(Route.favorites)
        case "settings": path.append(Route.settings)
        default: break
        }
        if defaults.bool(forKey: "startRadioFull"), let first = store.stations.first(where: { $0.country == "DZ" }) ?? store.stations.first {
            radio.play(first, queue: store.stations)
            radio.showFullScreen = true
        }
    }
}
