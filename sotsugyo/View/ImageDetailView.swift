import SwiftUI
import AVFoundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import UniformTypeIdentifiers

struct ImageDetailView: View {
    let image: UIImage?
    let documentId: String
    let folderId: String

    @StateObject private var model = ChekiDetailModel()
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @State private var reloadID = UUID()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .accessibilityLabel("チェキの写真")
                } else {
                    ContentUnavailableView("画像を表示できません", systemImage: "photo")
                }

                if let date = model.date {
                    Text(date, format: .dateTime.year().month().day().hour().minute())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                details
            }
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
            .padding()
        }
        .background(Color(uiColor: .systemBackground))
        .navigationTitle("チェキ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let image {
                    ShareLink(
                        item: ChekiShareImage(image: image),
                        preview: SharePreview("チェキ", image: Image(uiImage: image))
                    ) {
                        Label("共有", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .task(id: "\(folderId)/\(documentId)/\(reloadID)") {
            await model.load(documentId: documentId, folderId: folderId)
        }
        .onDisappear { model.pause() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { model.pause() }
        }
    }

    @ViewBuilder
    private var details: some View {
        if model.isLoading {
            ProgressView("チェキの情報を読み込み中")
                .frame(maxWidth: .infinity)
                .padding()
        } else if model.loadFailed {
            VStack(spacing: 8) {
                Text("チェキの情報を読み込めませんでした")
                    .foregroundStyle(.secondary)
                Button("再読み込み") { reloadID = UUID() }
                    .frame(minHeight: 44)
            }
        } else if let music = model.music {
            VStack(alignment: .leading, spacing: 12) {
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                    : AnyLayout(HStackLayout(spacing: 12))

                layout {
                    AsyncImage(url: URL(string: music.imageName)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Image(systemName: "music.note")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(uiColor: .tertiarySystemFill))
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(music.trackName)
                            .font(.headline)
                        if !music.artistName.isEmpty {
                            Text(music.artistName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if model.previewURL != nil {
                        Button(action: model.togglePlayback) {
                            Label(model.isPlaying ? "一時停止" : "試聴", systemImage: model.isPlaying ? "pause.fill" : "play.fill")
                                .labelStyle(.iconOnly)
                                .font(.title3)
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.circle)
                    }
                }

                if let error = model.playbackError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if model.isBuffering {
                    ProgressView("音楽を読み込み中")
                        .font(.footnote)
                } else if model.previewURL == nil {
                    Text("この曲は試聴できません")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        } else {
            Label("音楽は設定されていません", systemImage: "music.note")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding()
        }
    }
}

// Export the full image as PNG, so sharing and saving use the same pixels and frame.
private struct ChekiShareImage: Transferable {
    let image: UIImage

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { item in
            guard let data = item.image.pngData() else {
                throw CocoaError(.fileWriteUnknown)
            }
            return data
        }
        .suggestedFileName("チェキ.png")
    }
}

@MainActor
private final class ChekiDetailModel: ObservableObject {
    @Published private(set) var date: Date?
    @Published private(set) var music: FirebaseMusic?
    @Published private(set) var isLoading = true
    @Published private(set) var loadFailed = false
    @Published private(set) var isPlaying = false
    @Published private(set) var isBuffering = false
    @Published private(set) var playbackError: String?

    private var player: AVPlayer?
    private var subscriptions = Set<AnyCancellable>()
    private var reachedEnd = false

    var previewURL: URL? {
        guard let value = music?.previewURL,
              let url = URL(string: value),
              ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
              url.host != nil else { return nil }
        return url
    }

    func load(documentId: String, folderId: String) async {
        pause()
        subscriptions.removeAll()
        player = nil
        reachedEnd = false
        date = nil
        music = nil
        playbackError = nil
        loadFailed = false
        isLoading = true

        do {
            guard let uid = Auth.auth().currentUser?.uid,
                  !documentId.isEmpty, !folderId.isEmpty else {
                throw CocoaError(.fileReadNoSuchFile)
            }
            let document = try await Firestore.firestore()
                .collection("users").document(uid)
                .collection("folders").document(folderId)
                .collection("photos").document(documentId).getDocument()
            try Task.checkCancellation()
            guard let data = document.data() else {
                throw CocoaError(.fileReadNoSuchFile)
            }
            date = (data["date"] as? Timestamp)?.dateValue()
            if let trackName = Self.metadataString(data["trackName"]) {
                music = FirebaseMusic(
                    id: documentId,
                    artistName: Self.metadataString(data["artistName"]) ?? "",
                    imageName: Self.metadataString(data["imageName"]) ?? "",
                    trackName: trackName,
                    trackId: Self.metadataString(data["id"]) ?? "",
                    previewURL: Self.metadataString(data["previewUrl"]) ?? ""
                )
            }
            isLoading = false
        } catch {
            guard !Task.isCancelled else { return }
            loadFailed = true
            isLoading = false
        }
    }

    private static func metadataString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        // Older records and readers use this placeholder for missing metadata.
        return trimmed.isEmpty || trimmed == "ないよ" ? nil : trimmed
    }

    func togglePlayback() {
        if isPlaying {
            pause()
            return
        }
        guard let url = previewURL else { return }
        playbackError = nil
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            if player == nil || player?.currentItem?.status == .failed {
                configurePlayer(url: url)
            }
            if reachedEnd {
                player?.seek(to: .zero)
                reachedEnd = false
            }
            player?.play()
        } catch {
            playbackError = "音楽を再生できませんでした。もう一度お試しください。"
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        isBuffering = false
    }

    private func configurePlayer(url: URL) {
        subscriptions.removeAll()
        reachedEnd = false
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        self.player = player

        player.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.isPlaying = status != .paused
                self?.isBuffering = status == .waitingToPlayAtSpecifiedRate
            }
            .store(in: &subscriptions)

        item.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                if status == .failed { self?.playbackFailed() }
            }
            .store(in: &subscriptions)

        NotificationCenter.default.publisher(for: AVPlayerItem.didPlayToEndTimeNotification, object: item)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.pause()
                self?.reachedEnd = true
            }
            .store(in: &subscriptions)

        NotificationCenter.default.publisher(for: AVPlayerItem.failedToPlayToEndTimeNotification, object: item)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.playbackFailed() }
            .store(in: &subscriptions)
    }

    private func playbackFailed() {
        pause()
        subscriptions.removeAll()
        player = nil
        playbackError = "音楽を再生できませんでした。もう一度お試しください。"
    }
}
