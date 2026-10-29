import AVFoundation
import Combine
import MediaPlayer
import SwiftUI

private func activateAudioSession() {
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.playback, mode: .default, options: [])
    try? session.setActive(true)
}

// MARK: - Live TV

/// Plays one live channel. A link that never starts is reported as failed after 15 seconds, so the
/// viewer is never left on an endless spinner.
final class LivePlayer: ObservableObject {
    enum State { case idle, loading, playing, failed }

    @Published private(set) var state: State = .idle
    let player = AVPlayer()

    private var cancellables = Set<AnyCancellable>()
    private var timeoutTask: Task<Void, Never>?

    init() {
        player.automaticallyWaitsToMinimizeStalling = true
        activateAudioSession()
    }

    func play(_ channel: Channel) {
        timeoutTask?.cancel()
        cancellables.removeAll()
        guard let url = URL(string: channel.url) else {
            state = .failed
            return
        }
        let item = AVPlayerItem(url: url)
        state = .loading

        item.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                if status == .failed { self?.fail() }
            }
            .store(in: &cancellables)

        player.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                if status == .playing {
                    self?.timeoutTask?.cancel()
                    self?.state = .playing
                }
            }
            .store(in: &cancellables)

        player.replaceCurrentItem(with: item)
        player.play()

        timeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            if Task.isCancelled { return }
            await MainActor.run {
                if self?.state == .loading { self?.fail() }
            }
        }
    }

    private func fail() {
        timeoutTask?.cancel()
        player.pause()
        state = .failed
    }

    func stop() {
        timeoutTask?.cancel()
        cancellables.removeAll()
        player.pause()
        player.replaceCurrentItem(with: nil)
        state = .idle
    }
}

/// The video surface: the whole picture upright, filling the screen when turned sideways.
struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer
    let fill: Bool

    final class SurfaceView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }

    func makeUIView(context: Context) -> SurfaceView {
        let view = SurfaceView()
        view.backgroundColor = .black
        view.playerLayer.player = player
        view.playerLayer.videoGravity = fill ? .resizeAspectFill : .resizeAspect
        return view
    }

    func updateUIView(_ view: SurfaceView, context: Context) {
        view.playerLayer.player = player
        view.playerLayer.videoGravity = fill ? .resizeAspectFill : .resizeAspect
    }
}

// MARK: - Radio

/// The radio session: one stream at a time, background audio, lock-screen and headset controls.
final class RadioPlayer: ObservableObject {
    static let shared = RadioPlayer()

    enum State { case idle, connecting, playing, paused, failed }

    @Published private(set) var station: RadioStation?
    @Published private(set) var state: State = .idle
    @Published private(set) var queue: [RadioStation] = []
    @Published var showFullScreen = false

    private let player = AVPlayer()
    private var cancellables = Set<AnyCancellable>()
    private var retries = 0

    private init() {
        activateAudioSession()
        configureRemoteCommands()
    }

    var isActive: Bool { station != nil && state != .idle }

    var hasNext: Bool { index.map { $0 + 1 < queue.count } ?? false }
    var hasPrevious: Bool { index.map { $0 > 0 } ?? false }

    private var index: Int? { queue.firstIndex { $0.id == station?.id } }

    func play(_ station: RadioStation, queue: [RadioStation]) {
        self.queue = queue.contains(station) ? queue : [station] + queue
        retries = 0
        start(station)
    }

    private func start(_ station: RadioStation) {
        cancellables.removeAll()
        self.station = station
        guard let url = URL(string: station.url) else {
            state = .failed
            return
        }
        state = .connecting
        activateAudioSession()
        let item = AVPlayerItem(url: url)

        item.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                if status == .failed { self?.retryOrFail() }
            }
            .store(in: &cancellables)

        player.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self else { return }
                switch status {
                case .playing:
                    self.retries = 0
                    self.state = .playing
                case .paused:
                    if self.state == .playing { self.state = .paused }
                default:
                    break
                }
                self.updateNowPlaying()
            }
            .store(in: &cancellables)

        player.replaceCurrentItem(with: item)
        player.play()
        updateNowPlaying()
    }

    /// Bounded automatic retry (three tries, growing pauses), then a visible failure with Retry.
    private func retryOrFail() {
        guard let station else { return }
        if retries < 3 {
            retries += 1
            let delay = UInt64(pow(2.0, Double(retries - 1)) * 1_000_000_000)
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: delay)
                await MainActor.run {
                    guard let self, self.station?.id == station.id, self.state != .playing else { return }
                    self.start(station)
                }
            }
        } else {
            state = .failed
            updateNowPlaying()
        }
    }

    func togglePlayPause() {
        switch state {
        case .playing, .connecting:
            player.pause()
            state = .paused
        case .paused:
            player.play()
            state = .connecting
        case .failed:
            retry()
        case .idle:
            break
        }
        updateNowPlaying()
    }

    func retry() {
        guard let station else { return }
        retries = 0
        start(station)
    }

    func next() {
        guard let i = index, i + 1 < queue.count else { return }
        retries = 0
        start(queue[i + 1])
    }

    func previous() {
        guard let i = index, i > 0 else { return }
        retries = 0
        start(queue[i - 1])
    }

    func stop() {
        cancellables.removeAll()
        player.pause()
        player.replaceCurrentItem(with: nil)
        station = nil
        state = .idle
        showFullScreen = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func updateNowPlaying() {
        guard let station else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: station.name,
            MPMediaItemPropertyArtist: "Annes IPTV",
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyPlaybackRate: state == .playing ? 1.0 : 0.0
        ]
    }

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            if self.state == .paused || self.state == .failed { self.togglePlayPause() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            if self.state == .playing || self.state == .connecting { self.togglePlayPause() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.next()
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.previous()
            return .success
        }
    }
}
