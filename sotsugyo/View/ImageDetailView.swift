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
                                        
                                        
                                        ShareLink(item: unwrappedImage, preview: SharePreview("Big Ben", image: unwrappedImage))
                                        
                                        
                                        
                                        
                                        
                                    }
                                )
                        }
                    }
                    
                    
                }
                
                VStack {
                    
                    if let music = viewModel.Music.first {
                        
                        HStack {
                            AsyncImage(url: URL(string: music.imageName)) { phase in
                                switch phase {
                                case .empty:
                                    // Placeholder image or view
                                    Image(systemName: "photo")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 100, height: 100)
                                case .success(let image):
                                    // Successfully loaded image
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 100, height: 100)
                                case .failure:
                                    // Failed to load image
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(.red)
                                        .frame(width: 100, height: 100)
                                @unknown default:
                                    // Placeholder image or view for unknown state
                                    Image(systemName: "photo")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 100, height: 100)
                                }
                            }
                            .padding(10)
                            VStack {
                                Text(music.trackName)
                                    .font(.headline)
                                    .padding(.top, 8)
                                
                                Text(music.artistName)
                                    .font(.subheadline)
                                    .padding(.top, 4)
                                
                                
                                
                            }
                            .padding(EdgeInsets(
                                top: 10,
                                leading: 27,
                                bottom: 10,
                                trailing: 27
                            ))
                            
                            
                        }
                        
                    } else {
                        Text("ないよ")
                    }
                    
                }
                
                .frame(width: 333)
                
                .onDisappear{
                    viewModel.stop()
                }
                
                .onAppear {
                    Task {
                        do {
                            try await viewModel.getDate()
                            try await viewModel.getMusic(documentId: tapdocumentId, folder: viewModel.folderDocument, friendUid: friendUid)
                            
                        } catch {
                            print("テキスト情報の取得に失敗しました: \(error)")
                        }
                    }
                    
                    
                }
                
                .background(Color.white)
                .onTapGesture {
                    viewModel.startPlay()
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
