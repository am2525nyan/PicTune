import AVFoundation
import Combine

@MainActor
final class MusicPreviewPlayer: ObservableObject {
    enum State { case idle, loading, playing }
    enum Issue {
        case noPreview
        case failed(String)

        var message: String {
            switch self {
            case .noPreview: return "この曲には試聴音源がありません。"
            case .failed(let message): return message
            }
        }
    }
    typealias ResolveTrack = (Track) async throws -> Track

    @Published private(set) var state: State = .idle
    @Published private(set) var issue: Issue?
    @Published private(set) var resolvedTrack: Track?
    private(set) var audioPlayer: AVPlayer?
    private let resolveTrack: ResolveTrack
    private var loadTask: Task<Void, Never>?
    private var requestID = UUID()
    private var statusObservation: NSKeyValueObservation?
    private var timeObservation: NSKeyValueObservation?
    private var notifications: [NSObjectProtocol] = []
    private var ownsAudioSession = false
    var message: String? { issue?.message }
    var hasNoPreview: Bool {
        if case .noPreview? = issue { return true }
        return false
    }

    init(resolveTrack: @escaping ResolveTrack = { try await AppleMusicAPI.shared.refreshTrack($0) }) {
        self.resolveTrack = resolveTrack
    }

    func toggle(_ track: Track) {
        if state != .idle {
            stop()
            return
        }
        stop()
        issue = nil
        resolvedTrack = nil
        state = .loading
        let currentRequest = requestID
        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let playableTrack: Track
                switch track.provider {
                case .appleMusic: playableTrack = try await resolveTrack(track)
                case .spotify: playableTrack = track
                case .unknown: throw AppleMusicError.unavailable
                }
                try Task.checkCancellation()
                guard requestID == currentRequest else { return }
                resolvedTrack = playableTrack
                guard let preview = playableTrack.previewURL,
                      let url = URL(string: preview), url.scheme == "https", url.host != nil else {
                    state = .idle
                    issue = .noPreview
                    return
                }
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
                ownsAudioSession = true
                let item = AVPlayerItem(url: url)
                let player = AVPlayer(playerItem: item)
                audioPlayer = player
                statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
                    let failed = item.status == .failed
                    Task { @MainActor [weak self] in
                        guard let self, self.requestID == currentRequest, failed else { return }
                        self.failPlayback()
                    }
                }
                timeObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
                    let status = player.timeControlStatus
                    Task { @MainActor [weak self] in
                        guard let self, self.requestID == currentRequest else { return }
                        switch status {
                        case .playing: self.state = .playing
                        case .waitingToPlayAtSpecifiedRate: self.state = .loading
                        default: break
                        }
                    }
                }
                for name in [AVPlayerItem.didPlayToEndTimeNotification, AVPlayerItem.failedToPlayToEndTimeNotification] {
                    notifications.append(NotificationCenter.default.addObserver(forName: name, object: item, queue: .main) { [weak self] _ in
                        Task { @MainActor [weak self] in
                            guard let self, self.requestID == currentRequest else { return }
                            if name == AVPlayerItem.failedToPlayToEndTimeNotification { self.failPlayback() }
                            else { self.stop() }
                        }
                    })
                }
                player.play()
            } catch {
                guard requestID == currentRequest, !Task.isCancelled else { return }
                state = .idle
                issue = .failed((error as? AppleMusicError)?.errorDescription
                    ?? "試聴できませんでした。通信状況を確認して、もう一度お試しください。")
            }
        }
    }

    func stop() {
        requestID = UUID()
        loadTask?.cancel()
        loadTask = nil
        statusObservation = nil
        timeObservation = nil
        notifications.forEach { NotificationCenter.default.removeObserver($0) }
        notifications = []
        audioPlayer?.pause()
        audioPlayer = nil
        state = .idle
        if ownsAudioSession {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            ownsAudioSession = false
        }
    }

    private func failPlayback() {
        stop()
        issue = .failed("試聴できませんでした。通信状況を確認して、もう一度お試しください。")
    }

    deinit {
        loadTask?.cancel()
        audioPlayer?.pause()
        notifications.forEach { NotificationCenter.default.removeObserver($0) }
    }
}
