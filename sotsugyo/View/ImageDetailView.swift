import SwiftUI

struct ImageDetailView: View {
    let photo: LibraryPhoto
    @ObservedObject var viewModel: MainContentModel
    @State private var isDownload = false
    var resolvePreview: MusicPreviewPlayer.ResolveTrack? = nil

    var body: some View {
        ZStack{
            Color(red: 229 / 255, green: 217 / 255, blue: 255 / 255, opacity: 1.0)
                .edgesIgnoringSafeArea(.all)
            VStack {
                VStack {
                    VStack{
                        if photo.record.date != nil {
                            Text("日付: \(photo.dateText)")
                                .padding()
                        } else {
                            Text("日付情報なし")
                                .padding()
                        }
                    }
                    .frame(width: 333, height: 40)
                    .background(Color.white)
                    ZStack{

                        Group {
                            let unwrappedImage = photo.image
                            Image(uiImage: unwrappedImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 333)
                                .navigationBarTitle("画像詳細", displayMode: .inline)
                                .navigationBarItems(
                                    trailing: HStack{
                                        Button (action: {
                                            viewModel.downloadFile(photo: photo)
                                            isDownload.toggle()
                                        } , label: {
                                            Image(systemName: "square.and.arrow.down")
                                        })
                                        .alert(isPresented: $isDownload) {
                                            Alert(
                                                title: Text("保存"),
                                                message: Text("カメラロールに保存しました！"),
                                                dismissButton: .default(Text("OK")))
                                        }

                                        ShareLink(item: unwrappedImage, preview: SharePreview("チェキ", image: unwrappedImage))

                                    }
                                )
                        }
                    }

                }

                VStack {

                    if let music = photo.record.music {

                        MusicAttachmentView(track: music.track, resolvePreview: resolvePreview)
                            .id(music.track.selectionID)
                    } else {
                        Label("音楽なし", systemImage: "music.note")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding()
                    }

                }

                .frame(width: 333)

                .background(Color.white)

            }

        }

    }
}
extension UIImage: Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.image)
    }

    var image: Image {
        Image(uiImage: self)
    }
}


struct MusicAttachmentView: View {
    let track: Track
    @StateObject private var player: MusicPreviewPlayer

    init(track: Track, resolvePreview: MusicPreviewPlayer.ResolveTrack? = nil) {
        self.track = track
        _player = StateObject(wrappedValue: MusicPreviewPlayer(resolveTrack: resolvePreview ?? {
            try await AppleMusicAPI.shared.refreshTrack($0)
        }))
    }

    private var displayedTrack: Track { player.resolvedTrack ?? track }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
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
            HStack {
                Button {
                    player.toggle(track)
                } label: {
                    Label(player.state == .idle ? "試聴" : "停止",
                          systemImage: player.state == .idle ? "play.fill" : "stop.fill")
                        .frame(minHeight: 32)
                }
                .buttonStyle(.bordered)
                .disabled(track.provider == .unknown)
                .accessibilityIdentifier("music.preview")
                if player.state == .loading { ProgressView().accessibilityLabel("試聴を準備中") }
                Spacer(minLength: 0)
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
    }
}
