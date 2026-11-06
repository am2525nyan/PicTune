import SwiftUI
import UniformTypeIdentifiers

struct ImageDetailView: View {
    let photo: LibraryPhoto

    var resolvePreview: MusicPreviewPlayer.ResolveTrack? = nil
    var saveEdits: ((LibraryPhoto, UIImage) async throws -> LibraryPhoto)? = nil
    @State private var editedPhoto: LibraryPhoto?
    @State private var isEditing = false

    private var displayedPhoto: LibraryPhoto { editedPhoto ?? photo }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(uiImage: displayedPhoto.image)
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
            if saveEdits != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("落書き", systemImage: "pencil.tip.crop.circle") { isEditing = true }
                        .accessibilityIdentifier("cheki.edit")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(
                    item: ChekiShareImage(image: displayedPhoto.image),
                    preview: SharePreview("チェキ", image: Image(uiImage: displayedPhoto.image))
                ) {
                    Label("共有", systemImage: "square.and.arrow.up")
                }
            }
        }
        .fullScreenCover(isPresented: $isEditing) {
            SavedPhotoEditorView(image: displayedPhoto.image) { image in
                guard let saveEdits else { return }
                editedPhoto = try await saveEdits(displayedPhoto, image)
            }
        }
        .onChange(of: photo.record.fileName) { _, _ in editedPhoto = nil }
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
                MusicArtwork(track: displayedTrack, size: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayedTrack.name).font(.headline)
                    Text(displayedTrack.artist).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            layout {
                if player.hasNoPreview {
                    Label("試聴音源なし", systemImage: "speaker.slash")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("music.previewUnavailable")
                } else if track.provider != .unknown {
                    previewButton
                }
                if let url = displayedTrack.serviceURL {
                    if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
                    Link("\(displayedTrack.provider.name)で聴く", destination: url)
                        .font(.subheadline)
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityIdentifier("music.serviceLink")
                }
            }
            if !player.hasNoPreview, let message = player.message {
                Text(message).font(.caption).foregroundStyle(.secondary)
                    .accessibilityIdentifier("music.previewMessage")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .onDisappear { player.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { player.stop() }
        }
    }

    private var previewButton: some View {
        Button {
            player.toggle(track)
        } label: {
            Group {
                switch player.state {
                case .idle:
                    if player.issue != nil {
                        Label("再試行", systemImage: "arrow.clockwise")
                    } else {
                        Label("試聴", systemImage: "play.fill")
                    }
                case .loading:
                    HStack(spacing: 8) {
                        ProgressView().accessibilityHidden(true)
                        Text("準備中…")
                        Image(systemName: "xmark").font(.caption.weight(.semibold))
                    }
                case .playing:
                    Label("停止", systemImage: "stop.fill")
                }
            }
            .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("music.preview")
        .accessibilityHint(player.state == .loading ? "試聴の準備をキャンセルします" : "")
    }
}
