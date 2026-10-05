//
//  Main ContentModel.swift
//  sotsugyo
//
//  Created by saki on 2023/11/29.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import Combine
import AVFoundation
import SwiftUI
import Kingfisher
import Photos
import PhotosUI

class MainContentModel: ObservableObject {
    
    @Published internal var isShowSheet = false
    @Published internal var images: [UIImage] = []
    @Published internal var foldersImages: [UIImage] = []
    @Published internal var isPresentingCamera = false
    @Published internal var dates: [String] = []
    @Published internal var folderDates: [String] = []
    @Published internal var Music: [FirebaseMusic] = []
    @Published internal var documentIdArray = [String]()
    @Published internal var folderDocumentIdArray = [String]()
    @Published internal var folderUrl = []
    @Published internal var folders = [String]()
    @Published internal var foldersDocumentId = [String]()
    @Published var folderImages: [String: [UIImage]] = [:]
    @Published internal var getimage = false
    @Published internal var folderDocument = String()
    @Published internal var photoDataCache: [String: Data] = [:]
    @Published internal var nfc = false
    @Published internal var mailAddress = ""
    @Published internal var name = ""
    @Published var isAnimating: Bool = false
    @Published internal var livePhoto : PHLivePhoto?
    
    
    
    @Published var userDataList: String = ""
    private var folderLoadID = UUID()
    var audioPlayer: AVPlayer?
    var url = URL.init(string: "https://www.hello.com/sample.wav")
    
    
    // ドキュメントディレクトリの「ファイルURL」（URL型）定義
    var documentDirectoryFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    
    // ドキュメントディレクトリの「パス」（String型）定義
    let filePath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
    let db = Firestore.firestore()
    
    
    
    func firstgetUrl() async throws {
        do {
            guard let uid = Auth.auth().currentUser?.uid else {
                throw NSError(domain: "FirebaseError", code: -1, userInfo: [NSLocalizedDescriptionKey: "uid is nil"])
            }
            
            var urlArray = [String]()
            DispatchQueue.main.async {
                self.images = []
                self.documentIdArray = []
                self.folderDocument = "all"
            }
            
            let ref = try await db.collection("users").document(uid).collection("folders").document("all").collection("photos").order(by: "date").getDocuments()
            
            for document in ref.documents {
                let data = document.data()
                let url = data["url"]
                
                if url != nil {
                    urlArray.append(url as! String)
                }
                let documentId = document.documentID
                
                DispatchQueue.main.async {
                    self.documentIdArray.append(documentId)
                    
                }
            }
            let storage = Storage.storage()
            let storageRef = storage.reference()
            
            if urlArray.count >= 3{
                
            var picphoto = urlArray.randomElement()
             
                
                var storageRef = storage.reference().child("images/\(picphoto!)")
                storageRef.downloadURL { url, error in
                    if (error != nil) {
                        print("Uh-oh, an error occurred!")
                    } else {
                        print("download success!! URL1:", url!)
                        let userdefaults = UserDefaults(suiteName: "group.PIcTune")
                        let stringUrl = url!.absoluteString
                        userdefaults!.set(stringUrl, forKey: "first")
                        
                    }
                }
                
              picphoto = urlArray.randomElement()
             
            storageRef = storage.reference().child("images/\(picphoto!)")
                storageRef.downloadURL { url, error in
                    if (error != nil) {
                        print("Uh-oh, an error occurred!")
                    } else {
                        print("download success!! URL2:", url!)
                        let userdefaults = UserDefaults(suiteName: "group.PIcTune")
                        let stringUrl = url!.absoluteString
                        userdefaults!.set(stringUrl, forKey: "second")
                        
                        
                    }
                }
      picphoto = urlArray.randomElement()
             
     storageRef = storage.reference().child("images/\(picphoto!)")
                storageRef.downloadURL { url, error in
                    if (error != nil) {
                        print("Uh-oh, an error occurred!")
                    } else {
                        print("download success!! URL3:", url!)
                        let userdefaults = UserDefaults(suiteName: "group.PIcTune")
                        let stringUrl = url!.absoluteString
                        userdefaults!.set(stringUrl, forKey: "third")
                        
                        
                    }
                }

   
                
            }
            
            
            for (index, photo) in urlArray.enumerated() {
                
                
                do {
                    let data = try await withUnsafeThrowingContinuation { (continuation: UnsafeContinuation<Data, Error>) in
                        let imageRef = storageRef.child("images/" + photo)
                        imageRef.getData(maxSize: 100 * 1024 * 1024) { data, error in
                            if let error = error {
                                continuation.resume(throwing: error)
                            } else if let data = data {
                                continuation.resume(returning: data)
                            }
                        }
                    }
                    DispatchQueue.main.async {
                        if index <= self.images.count {
                            let image = UIImage(data: data)
                            
                            self.images.insert(image!, at: index)
                            
                        } else {
                            print("Index out of range. Ignoring data insertion.")
                        }
                    }
                } catch {
                    print("Error occurred! : \(error)")
                }
            }
            
            
            
        }
        if let currentUser = Auth.auth().currentUser {
            let uid = currentUser.uid
            
            try await db.collection("users").document(uid).collection("folders").document("all").updateData(["title": "all","date": FieldValue.serverTimestamp()])
            
            
            
            
        }
    }
    
    
    func getUrl() async throws {
        do {
            let uid = Auth.auth().currentUser?.uid
            var urlArray = [String]()
            
            let document = try await db.collection("users").document(uid ?? "").getDocument()
            let data = document.data()
            let date = data?["date"]
            
            if date != nil {
                let ref = try await db.collection("users").document(uid!).collection("folders").document("all").collection("photos").whereField("date", isGreaterThanOrEqualTo: date as Any).order(by: "date").getDocuments()
                
                for document in ref.documents {
                    let data = document.data()
                    let url = data["url"]
                    if url != nil {
                        urlArray.append(url as! String)
                    }
                    let documentId = document.documentID
                    DispatchQueue.main.async {
                        self.documentIdArray.append(documentId)
                        
                    }
                }
                
                let storage = Storage.storage()
                let storageRef = storage.reference()
                for (index, photo) in urlArray.enumerated() {
                    if let cachedData = photoDataCache[photo] {
                        let image = UIImage(data: cachedData)
                        DispatchQueue.main.async {
                            self.images.insert(image!, at: index)
                        }
                    } else {
                        let imageRef = storageRef.child("images/" + photo)
                        do {
                            
                            let data = try await withUnsafeThrowingContinuation { (continuation: UnsafeContinuation<Data, Error>) in
                                imageRef.getData(maxSize: 100 * 1024 * 1024) { data, error in
                                    if let error = error {
                                        continuation.resume(throwing: error)
                                    } else if let data = data {
                                        continuation.resume(returning: data)
                                    }
                                }
                            }
                            
                            DispatchQueue.main.async {
                                self.photoDataCache[photo] = data
                            }
                            let image = UIImage(data: data)
                            DispatchQueue.main.async {
                                self.images.insert(image!, at: index)
                            }
                        } catch {
                            print("Error occurred during download! : \(error)")
                            
                        }
                    }
                }
            }
            
            try await db.collection("users").document(uid ?? "").setData(["date": FieldValue.serverTimestamp()])
        } catch {
            throw error
        }
    }
    
    
    
    
    func getDate() async throws {
        DispatchQueue.main.async {
            self.dates = []
        }
        do {
            guard let uid = Auth.auth().currentUser?.uid else {
                throw NSError(domain: "FirebaseError", code: -1, userInfo: [NSLocalizedDescriptionKey: "uid is nil"])
            }
            let ref = try await db.collection("users").document(uid).collection("folders").document("all").collection("photos").order(by: "date").getDocuments()
            
            for document in ref.documents {
                let data = document.data()
                let date = data["date"] as! Timestamp
                
                let formatterDate = DateFormatter()
                formatterDate.dateFormat = "yyyy-MM-dd-HH:mm"
                let createdDate = formatterDate.string(from: date.dateValue())
                
                DispatchQueue.main.async {
                    self.dates.append(createdDate)
                }
            }
        } catch {
            throw error
        }
    }
    func getMusic(documentId: String,folder: String,friendUid: String) async throws{
        DispatchQueue.main.async {
            self.Music = []
        }
        
        if let currentUser = Auth.auth().currentUser {
            let uid = currentUser.uid
            
            let ref = try await db.collection("users").document(uid).collection("folders").document(folder).collection("photos").document(documentId).getDocument()
            let data = ref.data()
            guard let trackId = data?["id"] as? String, !trackId.isEmpty else { return }
            let artistName = data?["artistName"] as? String ?? ""
            let imageName = data?["imageName"] as? String ?? ""
            let trackName = data?["trackName"] as? String ?? ""
            let id = data?["id"] as?String ?? "ないよ"
            let previewUrl = data?["previewUrl"] as? String ?? ""
            
            DispatchQueue.main.async {
                self.Music.append(FirebaseMusic(id: documentId, artistName: artistName , imageName: imageName , trackName: trackName , trackId: id , previewURL: previewUrl )
                )
            }
            
            
            
        }
    }
    
    func makeFolder(folderName: String){
     
        
        if let currentUser = Auth.auth().currentUser {
            let uid = currentUser.uid
            let folders = UUID().uuidString
            db.collection("users").document(uid).collection("folders").document(folders).setData([
                "title": folderName,
                "date": FieldValue.serverTimestamp()
            ])
            DispatchQueue.main.async {
                self.folders.insert(folderName, at:1)
                self.foldersDocumentId.insert(folders, at:1)
            }
            
            db.collection("users").document(uid).collection("folders").document("all").updateData(["title": "all","date": FieldValue.serverTimestamp()])
        }
        
        
    }
    
    @MainActor
    func getFolder() async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let snapshot = try await db.collection("users").document(uid).collection("folders")
            .order(by: "date", descending: true).getDocuments()
        folders = snapshot.documents.map { $0.data()["title"] as? String ?? "名称未設定" }
        foldersDocumentId = snapshot.documents.map(\.documentID)
    }

    func appendFolder(folderId: Int, index: Int) {
        let document = self.documentIdArray[index]
        let destinationFolderID = self.foldersDocumentId[folderId]
        
        if let currentUser = Auth.auth().currentUser {
            let uid = currentUser.uid
            
            let newCollectionName = "photos"
            
            let destinationCollectionRef = db.collection("users").document(uid).collection("folders").document(destinationFolderID).collection(newCollectionName).document()
            
            let batch = db.batch()
            
            let sourceDocumentRef =  db.collection("users").document(uid).collection("folders").document("all").collection("photos").document(document)
            sourceDocumentRef.getDocument { (documentSnapshot, error) in
                if let error = error {
                    print("Error getting document: \(error)")
                } else if let data = documentSnapshot?.data() {
                    batch.setData(data, forDocument: destinationCollectionRef)
                    batch.commit() { err in
                        if let err = err {
                            print("バッチの書き込みエラー: \(err)")
                        } else {
                            print("データが正常にコピーされました！")
                            
                        }
                    }
                }
            }
        }
    }
    
    
    
    // Publish a complete snapshot only if this folder is still selected.
    @MainActor
    func FoldergetUrl(folderId: Int) async throws {
        guard foldersDocumentId.indices.contains(folderId),
              let uid = Auth.auth().currentUser?.uid else { return }
        let folderID = foldersDocumentId[folderId]
        folderDocument = folderID
        let requestID = UUID()
        folderLoadID = requestID
        images = []
        documentIdArray = []
        dates = []
        userDataList = ""

        let snapshot = try await db.collection("users").document(uid).collection("folders")
            .document(folderID).collection("photos").order(by: "date").getDocuments()
        var loadedImages: [UIImage] = []
        var loadedIDs: [String] = []
        var loadedDates: [String] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH:mm"
        for document in snapshot.documents {
            guard folderDocument == folderID, folderLoadID == requestID else { return }
            let photo = document.data()
            guard let path = photo["url"] as? String else { continue }
            let data: Data
            if let cached = photoDataCache[path] {
                data = cached
            } else {
                data = try await Storage.storage().reference().child("images/" + path)
                    .data(maxSize: 100 * 1024 * 1024)
                photoDataCache[path] = data
            }
            guard let image = UIImage(data: data) else { continue }
            loadedImages.append(image)
            loadedIDs.append(document.documentID)
            loadedDates.append((photo["date"] as? Timestamp).map {
                formatter.string(from: $0.dateValue())
            } ?? "")
        }
        guard folderDocument == folderID, folderLoadID == requestID else { return }
        images = loadedImages
        documentIdArray = loadedIDs
        dates = loadedDates
        try await db.collection("users").document(uid).setData(["date": FieldValue.serverTimestamp()])
    }

    @MainActor
    func saveLetter(_ text: String, folderID: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw folderError("ログイン状態を確認して、もう一度お試しください。")
        }
        try await db.collection("users").document(uid).collection("folders")
            .document(folderID).updateData(["letter": text])
        if folderDocument == folderID { userDataList = text }
    }

    func loadLetter(folderID: String) async throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw folderError("ログイン状態を確認して、もう一度お試しください。")
        }
        let document = try await db.collection("users").document(uid).collection("folders")
            .document(folderID).getDocument()
        guard document.exists else { throw folderError("フォルダが見つかりませんでした。") }
        return document.data()?["letter"] as? String ?? ""
    }

    private func folderError(_ message: String) -> NSError {
        NSError(domain: "PicTune.Folder", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    func getLetter(){
        if let currentUser = Auth.auth().currentUser {
            let uid = currentUser.uid
            db.collection("users").document(uid).collection("folders").document(folderDocument).getDocument { (document, error) in
                if let document = document, document.exists {
                    let data = document.data()
                    let letter = data?["letter"] as? String ?? ""
                    self.userDataList = letter
                    
                } else {
                    print("Document does not exist")
                    DispatchQueue.main.async {
                        self.userDataList = ""
                    }
                }
            }
        }
    }
    
    func deletePhoto(document: String){
        if let currentUser = Auth.auth().currentUser {
            let uid = currentUser.uid
            db.collection("users").document(uid).collection("folders").document(folderDocument).collection("photos").document(document).delete()
        }
    }
    @MainActor
    func deleteFolder(id: String) async throws {
        guard id != "all", !id.isEmpty else { throw folderError("このフォルダは削除できません。") }
        guard let uid = Auth.auth().currentUser?.uid else {
            throw folderError("ログイン状態を確認して、もう一度お試しください。")
        }
        let reference = db.collection("users").document(uid).collection("folders").document(id)
        // Update the visible list only after the server accepts the deletion.
        try await reference.delete()
        if let index = foldersDocumentId.firstIndex(of: id), folders.indices.contains(index) {
            foldersDocumentId.remove(at: index)
            folders.remove(at: index)
        }
        if folderDocument == id {
            folderDocument = "all"
            images = []
            documentIdArray = []
            dates = []
            userDataList = ""
            getimage.toggle()
        }
    }

    func getNFCData( NFCUid: String, NFCfolderid: String)async throws{
        
        if nfc == false{
            DispatchQueue.main.async {
                self.nfc = true
            }
            if let currentUser = Auth.auth().currentUser {
                let uid = currentUser.uid
                
                Task{
                    do{
                        try await  db.collection("users").document(uid).collection("folders").document("all").updateData(["title": "all","date": FieldValue.serverTimestamp()])
                    }catch{
                        print(error)
                    }
                }
                
                var urlArray = [String]()
                
                let document = try await db.collection("users").document(NFCUid).collection("folders").document(NFCfolderid).getDocument()
                let data = document.data()
                let title = data?["title"] as? String ?? "デフォルトのタイトル"
                let letter = data?["letter"] as? String ?? ""
                let date = data?["date"]  ?? FieldValue.serverTimestamp()
                
                DispatchQueue.main.async {
                    self.folders.append(title)
                    self.foldersDocumentId.append(NFCfolderid)
                }
                
                try await db.collection("users").document(uid).collection("folders").document(NFCfolderid).setData(["title": title, "date": FieldValue.serverTimestamp(),"letter": letter])
                let destinationCollectionRef =  db.collection("users").document(uid).collection("folders").document(NFCfolderid).collection("photos")
                
                
                let sourceCollectionRef = try await db.collection("users").document(NFCUid).collection("folders").document(NFCfolderid).collection("photos").order(by: "date").getDocuments()
                
                for document in sourceCollectionRef.documents {
                    let data = document.data()
                    let DocumentID = document.documentID
                    _ = try await destinationCollectionRef.addDocument(data: data)
                    let url = data["url"]
                    if url != nil {
                        urlArray.append(url as! String)
                    }
                    let ref = try await db.collection("users").document(uid).collection("folders").document(NFCfolderid).collection("photos").document(DocumentID).getDocument()
                    let data2 = ref.data()
                    guard let trackId = data2?["id"] as? String, !trackId.isEmpty else { continue }
                    let artistName =  data2?["artistName"] as?String ?? "ないよ"
                    let imageName =  data2?["imageName"] as?String ?? "ないよ"
                    let trackName =  data2?["trackName"] as?String ?? "ないよ"
                    let id = data2?["id"] as?String ?? "ないよ"
                    let previewUrl = data2?["previewUrl"] as?String ?? ""
                    
                    DispatchQueue.main.async {
                        self.Music.append(FirebaseMusic(id: DocumentID, artistName: artistName , imageName: imageName , trackName: trackName , trackId: id , previewURL: previewUrl )
                        )
                    }
                    
                }
            }
            DispatchQueue.main.async {
                self.nfc = false
            }
            
        }else{
            print("2回目")
        }
        
        
        
    }
    
    func downloadFile(documentId: String, folderId: String) {
        let storage = Storage.storage()
        if let currentUser = Auth.auth().currentUser {
            let uid = currentUser.uid
            let docRef = db.collection("users").document(uid).collection("folders").document(folderId).collection("photos").document(documentId)
            
            docRef.getDocument { document, error in
                if let error = error {
                    print("Error getting document: \(error.localizedDescription)")
                    return
                }
                
                if let data = document?.data(), let fileName = data["url"] as? String {
                    print("File Name: \(fileName)")
                    let storageRef = Storage.storage().reference().child("images/"+fileName)
                    
                    storageRef.getData(maxSize: 5 * 1024 * 1024) { data, error in
                        if let error = error {
                            print("Error downloading image: \(error.localizedDescription)")
                            return
                        }
                        
                        if let imageData = data, let image = UIImage(data: imageData) {
                            self.saveImageToCameraRoll(image: image)
                        }
                    }
                } else {
                    print("Document does not exist or does not contain 'url' key.")
                }
            }
        }
        
    }
    private func saveImageToCameraRoll(image: UIImage) {
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        } completionHandler: { success, error in
            if let error = error {
                print("Error saving image to camera roll: \(error.localizedDescription)")
            } else {
                print("Image saved to camera roll successfully.")
            }
        }
    }
    func startPlay() {
        guard let preview = Music.first?.previewURL,
              !preview.isEmpty,
              let previewURL = URL(string: preview),
              previewURL.scheme == "https" || previewURL.scheme == "http" else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer = AVPlayer(url: previewURL)
            audioPlayer?.play()
        } catch {
            print(error)
        }
    }

    func stop() {
        DispatchQueue.main.async {
            self.audioPlayer?.pause()
        }
    }
    func startAnimation() {
        DispatchQueue.main.async {
            self.isAnimating = true
        }
    }
    func stopAnimation() {
        DispatchQueue.main.async {
            self.isAnimating = false
        }
    }
    
  
}
