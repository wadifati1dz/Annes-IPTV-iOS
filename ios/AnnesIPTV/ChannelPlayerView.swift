import SwiftUI
import AVFoundation

/// The live channel player. Upright it shows the whole picture; sideways it fills the screen. A tap
/// shows the controls for two seconds; the list button opens a side panel with the app crest, a
/// bouquet drop-down and the channels as round logos, so the viewer can zap without leaving.
struct ChannelPlayerView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @StateObject private var live = LivePlayer()

    @State private var current: Channel
    @State private var zapList: [Channel]
    @State private var bouquetKey: String?
    @State private var showList = false
    @State private var showControls = true
    @State private var hideTask: Task<Void, Never>?
    @State private var actionTarget: Channel?

    init(channel: Channel, list: [Channel]) {
        _current = State(initialValue: channel)
        _zapList = State(initialValue: list)
        _bouquetKey = State(initialValue: channel.bouquetKey)
    }

    private var otherLabel: String {
        NSLocalizedString("other", bundle: bundle(for: locale), comment: "")
    }

    private var panelChannels: [Channel] {
        guard let bouquetKey else { return store.channels }
        return store.channels.filter { $0.bouquetKey == bouquetKey }
    }

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            ZStack {
                Color.black.ignoresSafeArea()
                PlayerLayerView(player: live.player, fill: landscape)
                    .ignoresSafeArea()
                    .onTapGesture { toggleControls() }

                switch live.state {
                case .loading:
                    ProgressView().progressViewStyle(.circular).tint(Theme.gold).scaleEffect(1.4)
                case .failed:
                    errorOverlay
                default:
                    EmptyView()
                }

                if showControls || live.state != .playing {
                    controlsOverlay
                }

                if showList {
                    listPanel(width: min(320, geo.size.width * 0.85))
                }
            }
        }
        .statusBarHidden(true)
        .onAppear { play(current) }
        .onDisappear { live.stop() }
        .onChange(of: live.state) { state in
            if state == .playing { scheduleHide() } else { hideTask?.cancel() }
        }
        .confirmationDialog(actionTarget?.name ?? "", isPresented: Binding(
            get: { actionTarget != nil },
            set: { if !$0 { actionTarget = nil } }
        ), titleVisibility: .visible) {
            if let target = actionTarget {
                Button(LocalizedStringKey(store.isFavorite(target.id) ? "favorites_remove" : "favorites_add")) {
                    store.toggleFavorite(target.id)
                }
                Button("delete", role: .destructive) { store.delete(target) }
            }
            Button("cancel", role: .cancel) {}
        }
    }

    // MARK: Controls

    private var controlsOverlay: some View {
        VStack {
            HStack {
                roundButton("chevron.backward") { dismiss() }
                Spacer()
                Text(current.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Color.black.opacity(0.5), in: Capsule())
                Spacer()
                roundButton("list.bullet") { showList.toggle() }
            }
            .padding(12)
            Spacer()
        }
        .transition(.opacity)
    }

    private func roundButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Color.black.opacity(0.5), in: Circle())
        }
    }

    private var errorOverlay: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill").font(.largeTitle).foregroundColor(Theme.gold)
            Text("error_stream").multilineTextAlignment(.center)
            HStack(spacing: 12) {
                Button { play(current) } label: { Label("retry", systemImage: "arrow.clockwise") }
                Button { zap(by: 1) } label: { Label("next_channel", systemImage: "forward.fill") }
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.gold)
            .foregroundColor(.black)
        }
        .padding(22)
        .background(Color.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 20))
        .padding(30)
    }

    // MARK: Side panel

    private func listPanel(width: CGFloat) -> some View {
        ZStack(alignment: .trailing) {
            Color.black.opacity(0.45).ignoresSafeArea().onTapGesture { showList = false }
            VStack(spacing: 10) {
                Image("AppLogo").resizable().scaledToFit().frame(height: 46)
                bouquetMenu
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(panelChannels) { channel in
                                row(channel).id(channel.id)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onAppear { proxy.scrollTo(current.id, anchor: .center) }
                }
            }
            .padding(12)
            .frame(width: width)
            .frame(maxHeight: .infinity)
            .background(Theme.capsule.opacity(0.96).ignoresSafeArea())
        }
        .transition(.move(edge: .trailing))
    }

    private var bouquetMenu: some View {
        Menu {
            Button("all") { selectBouquet(nil) }
            ForEach(store.bouquets) { item in
                Button {
                    selectBouquet(item.key)
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
                Text(bouquetKey.map { bouquetDisplayName($0, locale: locale, otherLabel: otherLabel) } ?? NSLocalizedString("all", bundle: bundle(for: locale), comment: ""))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.down").foregroundColor(Theme.gold)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.gold.opacity(0.6), lineWidth: 1))
        }
    }

    private func row(_ channel: Channel) -> some View {
        let isCurrent = channel.id == current.id
        return HStack(spacing: 12) {
            LogoView(url: channel.logo, name: channel.name)
                .frame(width: 42, height: 42)
                .clipShape(Circle())
            Text(channel.name)
                .font(.subheadline.weight(isCurrent ? .semibold : .regular))
                .foregroundColor(isCurrent ? Theme.gold : .white)
                .lineLimit(1)
            Spacer()
            if store.isFavorite(channel.id) {
                Image(systemName: "heart.fill").font(.caption).foregroundColor(Theme.gold)
            }
        }
        .padding(.leading, 6).padding(.trailing, 14).padding(.vertical, 6)
        .background(isCurrent ? Theme.gold.opacity(0.18) : Color.white.opacity(0.05), in: Capsule())
        .overlay(Capsule().stroke(isCurrent ? Theme.gold.opacity(0.7) : .clear, lineWidth: 1))
        .contentShape(Capsule())
        .onTapGesture {
            showList = false
            play(channel)
        }
        .onLongPressGesture { actionTarget = channel }
    }

    // MARK: Behavior

    private func selectBouquet(_ key: String?) {
        bouquetKey = key
        zapList = panelChannels
    }

    private func play(_ channel: Channel) {
        current = channel
        live.play(channel)
        showControls = true
    }

    private func zap(by step: Int) {
        let list = zapList.isEmpty ? store.channels : zapList
        guard !list.isEmpty else { return }
        let index = list.firstIndex { $0.id == current.id } ?? -1
        let next = (index + step + list.count) % list.count
        play(list[next])
    }

    private func toggleControls() {
        if showList { showList = false; return }
        withAnimation { showControls.toggle() }
        if showControls { scheduleHide() }
    }

    /// The controls tuck away two seconds after they appear, but only while the picture is playing.
    private func scheduleHide() {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if Task.isCancelled { return }
            await MainActor.run {
                if live.state == .playing && !showList { withAnimation { showControls = false } }
            }
        }
    }
}
