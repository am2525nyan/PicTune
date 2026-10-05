//
//  ImageDetailView.swift
//  sotsugyo
//
//  Created by saki on 2023/12/04.
//

import SwiftUI
import Photos
import FirebaseStorage
import FirebaseAuth
import FirebaseFirestore
// ImageDetailView.swift
struct ImageDetailView: View {
    @Binding var image: UIImage?
    @Binding var documentId: String
    @Binding var tapdocumentId: String
    @Binding var index: Int
    @State private var tracks: [Track] = []
    @State private var livePhoto = false
    @ObservedObject var viewModel: MainContentModel
    
    @Binding var friendUid: String
    var selectedIndex: Int
    @State var isDownload = false
    var resolvePreview: MusicPreviewPlayer.ResolveTrack? = nil
    @State private var musicLoadError: String?
    
    
    var body: some View {
        ZStack{
            Color(red: 229 / 255, green: 217 / 255, blue: 255 / 255, opacity: 1.0)
                .edgesIgnoringSafeArea(.all)
            VStack {
                VStack {
                    VStack{
                        if selectedIndex < viewModel.dates.count {
                            let correspondingDate = viewModel.dates[selectedIndex]
                            Text("日付: \(correspondingDate)")
                                .padding()
                        } else {
                            Text("日付情報なし")
                                .padding()
                        }
                    }
                    .frame(width: 333, height: 40)
                    .background(Color.white)
                    ZStack{
                        
                        if let unwrappedImage = image {
                            Image(uiImage: unwrappedImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 333)
                                .navigationBarTitle("画像詳細", displayMode: .inline)
                                .navigationBarItems(
                                    trailing: HStack{
                                        Button (action: {
                                            viewModel.downloadFile(documentId: documentId, folderId: viewModel.folderDocument)
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
                    
                    if let music = viewModel.Music.first {
                        
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
                
                .task(id: tapdocumentId) {
                    musicLoadError = nil
                    do {
                        try await viewModel.getMusic(documentId: tapdocumentId, folder: viewModel.folderDocument, friendUid: friendUid)
                    } catch {
                        if !Task.isCancelled { musicLoadError = "曲の情報を取得できませんでした。画面を開き直してください。" }
                    }
                }
                .background(Color.white)
                if let musicLoadError {
                    Text(musicLoadError).font(.caption).foregroundStyle(.secondary)
                }
                
                
                
            }
            
        }
        
        
    }
    func downloadFile(documentId: String, folderId: String) {
        let storage = Storage.storage()
        let storageRef = storage.reference()
        let db = Firestore.firestore()
        
        if let currentUser = Auth.auth().currentUser {
            let uid = currentUser.uid
            db.collection("users").document(uid).collection("folders").document(folderId).collection("photos").document(documentId).getDocument { document, _ in
                if let data = document?.data(), let fileName = data["url"] as? String {
                    let localURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                    
                    // ダウンロードを実行
                    storageRef.child(fileName).write(toFile: localURL) { localURL, error in
                        if let error = error {
                            print("Error downloading file: \(error)")
                        } else {
                            print("Download success! Local URL: \(localURL?.path ?? "")")
                            
                            // カメラロールに保存
                            saveToCameraRoll(imageURL: localURL)
                        }
                    }
                } else {
                    print("Failed to get document data or file name from Firestore")
                }
            }
        }
    }
    
    
    func saveToCameraRoll(imageURL: URL?) {
        guard let imageURL = imageURL else { return }
        
        // カメラロールに保存
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: imageURL)
        }) { success, error in
            if success {
                print("Image saved to camera roll")
            } else {
                print("Error saving image to camera roll: \(error?.localizedDescription ?? "")")
            }
        }
    }
    
    func sharePhoto(documentId: String, folderId: String) {
        
        
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
