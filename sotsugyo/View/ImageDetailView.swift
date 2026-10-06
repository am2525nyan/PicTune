import SwiftUI
import UniformTypeIdentifiers

struct ImageDetailView: View {
    let photo: LibraryPhoto

    var resolvePreview: MusicPreviewPlayer.ResolveTrack? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(uiImage: photo.image)
                    .resizable()
                    .scaledToFit()
                    .overlay {
                        Rectangle()
                            .strokeBorder(Color(uiColor: .separator).opacity(0.35), lineWidth: 0.5)
                    }
                    .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
                    .accessibilityLabel("チェキの写真")

                if let date = photo.record.date {
                    Text(date, format: .dateTime.year().month().day().hour().minute())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("cheki-date")
                }

                details
            }
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("チェキ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(
                    item: ChekiShareImage(image: photo.image),
                    preview: SharePreview("チェキ", image: Image(uiImage: photo.image))
                ) {
                    Label("共有", systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    @ViewBuilder
    private var details: some View {
        if let music = photo.record.music {
            MusicAttachmentView(track: music.track, resolvePreview: resolvePreview)
                .id(music.track.selectionID)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
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

struct MusicAttachmentView: View {
    let track: Track
    @StateObject private var player: MusicPreviewPlayer
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase

    init(track: Track, resolvePreview: MusicPreviewPlayer.ResolveTrack? = nil) {
        self.track = track
        _player = StateObject(wrappedValue: MusicPreviewPlayer(resolveTrack: resolvePreview ?? {
            try await AppleMusicAPI.shared.refreshTrack($0)
        }))
    }

    private var displayedTrack: Track { player.resolvedTrack ?? track }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                : AnyLayout(HStackLayout(spacing: 12))

            layout {
                AsyncImage(url: displayedTrack.albumImages.first.flatMap(URL.init(string:))) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    Image(systemName: "music.note").font(.title).foregroundStyle(.secondary)
                }
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayedTrack.name).font(.headline)
                    Text(displayedTrack.artist).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            layout {
                Button {
                    player.toggle(track)
                } label: {
                    Label(player.state == .idle ? "試聴" : "停止",
                          systemImage: player.state == .idle ? "play.fill" : "stop.fill")
                        .frame(minHeight: 44)
                }
                .buttonStyle(.bordered)
                .disabled(track.provider == .unknown)
                .accessibilityIdentifier("music.preview")
                if player.state == .loading { ProgressView().accessibilityLabel("試聴を準備中") }
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
                if let url = displayedTrack.serviceURL {
                    Link("\(displayedTrack.provider.name)で聴く", destination: url)
                        .font(.subheadline)
                        .accessibilityIdentifier("music.serviceLink")
                }
            }
            if let message = player.message {
                Text(message).font(.caption).foregroundStyle(.secondary)
                    .accessibilityIdentifier("music.previewMessage")
            }
        }
        .padding()
        .onDisappear { player.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { player.stop() }
        }
    }
}
