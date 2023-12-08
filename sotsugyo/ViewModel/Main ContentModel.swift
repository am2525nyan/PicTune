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

class MainContentModel: ObservableObject {
    
    
    @Published internal var isShowSheet = false
    @Published internal var images: [UIImage] = []
    @Published internal var isPresentingCamera = false
    @Published internal var dates: [String] = []
    @Published internal var Music: [FirebaseMusic] = []
    @Published internal var documentIdArray = []
    var audioPlayer: AVPlayer?
    var url = URL.init(string: "https://www.hello.com/sample.wav")
    func firstgetUrl() async throws{
        do{
            guard let uid = Auth.auth().currentUser?.uid else {
                throw NSError(domain: "FirebaseError", code: -1, userInfo: [NSLocalizedDescriptionKey: "uid is nil"])
            }
            
            let db = Firestore.firestore()
            
            var urlArray = [String]()
            DispatchQueue.main.async {
                self.images = []
                self.documentIdArray = []
            }
            
            
            let ref = try await db.collection("users").document(uid).collection("photo").order(by: "date").getDocuments()
            
            for document in ref.documents {
                
                let data = document.data()
                let url = data["url"]
                if url != nil{
                    urlArray.append(url as! String)
                }
                let documentId = document.documentID
                DispatchQueue.main.async {
                    self.documentIdArray.append(documentId)
                }
            }
            let storage = Storage.storage()
            
            let storageRef = storage.reference()
            for photo in urlArray{
                let imageRef = storageRef.child("images/" + photo)
                imageRef.getData(maxSize: 100 * 1024 * 1024) { data, error in
                    if let error = error {
                        print("Error occurred! : \(error)")
                    } else {
                        let image = UIImage(data: data!)
                        DispatchQueue.main.async {
                            self.images.append(image!)
                            
                        }
                    }
                }
                
            }
            
            
        } catch{
            throw error
        }
    }
    
    func getUrl() async throws{
        let db = Firestore.firestore()
        let uid = Auth.auth().currentUser?.uid
        var urlArray = [String]()
        let document =  try await db.collection("users").document(uid ?? "").getDocument()
        let data = document.data()
        let date = data?["date"]
        if date != nil{
            do{
                let ref = try await db.collection("users").document(uid ?? "").collection("photo").whereField("date", isGreaterThanOrEqualTo: date as Any).order(by: "date").getDocuments()
                
                for document in ref.documents {
                    
                    let data = document.data()
                    let url = data["url"]
                    if url != nil{
                        urlArray.append(url as! String)
                    }
                    let documentId = document.documentID
                    DispatchQueue.main.async {
                        self.documentIdArray.append(documentId)
                        print(self.documentIdArray,"AAA")
                    }
                    
                }
                let storage = Storage.storage()
                
                let storageRef = storage.reference()
                for photo in urlArray{
                    let imageRef = storageRef.child("images/" + photo)
                    imageRef.getData(maxSize: 100 * 1024 * 1024) { data, error in
                        if let error = error {
                            print("Error occurred! : \(error)")
                        } else {
                            let image = UIImage(data: data!)
                            DispatchQueue.main.async {
                                self.images.append(image!)
                            }
                            
                        }
                    }
                    
                }
                
            }catch{
                throw error
            }
            
            try await db.collection("users").document(uid ?? "").setData(["date": FieldValue.serverTimestamp()])
        }
    }
    
    
    func saveUserData(){
        
        let db = Firestore.firestore()
        
        if let currentUser = Auth.auth().currentUser {
            let uid = currentUser.uid
            db.collection("users").document(uid ).collection("personal").document("info").setData([
                "uid": uid ,
                "email": currentUser.email ?? "",
                "name": currentUser.displayName ?? ""
            ]) { error in
                if let error = error {
                    print("データの保存に失敗しました: \(error.localizedDescription)")
                } else {
                    print("データがFirestoreに保存されました")
                }
            }
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
            
            let db = Firestore.firestore()
            let ref = try await db.collection("users").document(uid).collection("photo").order(by: "date").getDocuments()
            
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
    func getMusic(documentId: String) async throws{
        DispatchQueue.main.async {
            self.Music = []
        }
        if let currentUser = Auth.auth().currentUser {
            let uid = currentUser.uid
            let db = Firestore.firestore()
            print(documentId,"dd")
            let ref = try await db.collection("users").document(uid).collection("photo").document(documentId).getDocument()
            let data = ref.data()
            let artistName =  data?["artistName"]
            let imageName =  data?["imageName"]
            let trackName =  data?["trackName"]
            let id = data?["id"]
            let previewUrl = data?["previewUrl"]
            DispatchQueue.main.async {
                self.Music.append(FirebaseMusic(id: documentId, artistName: artistName as! String, imageName: imageName as! String, trackName: trackName as! String, trackId: id as! String, previewURL: previewUrl as! String)
                )
            }
            DispatchQueue.main.async {
                print(self.Music)
            }
        }
    }
    
    
    func startPlay() {
        url =  URL.init(string: Music.first!.previewURL )
        let sampleUrl = URL.init(string: "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview115/v4/8f/c1/32/8fc1329a-bf7d-03f2-3082-6536f60666ee/mzaf_1239907852510333018.plus.aac.p.m4a")
        audioPlayer = AVPlayer.init(playerItem: AVPlayerItem(url: url ?? sampleUrl! ))
        
        // 再生が終わった際のイベント定義
        NotificationCenter.default
            .addObserver(self, selector: #selector(playerDidFinishPlaying),
                         name: .AVPlayerItemDidPlayToEndTime,
                         object: audioPlayer?.currentItem)
        
        // 秒数の表示
        Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { timer in
            if let audioPlayer = self.audioPlayer,
               let currentItem = audioPlayer.currentItem,
               currentItem.status == .readyToPlay {
                let timeElapsed = CMTimeGetSeconds(audioPlayer.currentTime()) // 現在の再生時間の取得
                let timeDuration = currentItem.duration.seconds
                
            }
        }
        
        audioPlayer?.play()
    }
    
    @objc func playerDidFinishPlaying(note: NSNotification) {
        // 再生が終わった際のイベント処理
    }
    
    func stop() {
        audioPlayer?.pause()
        // audioPlayer?.play() で再開
    }
    
    // 音声再生スピードの変更
    func changeSpeed(speed: Float) {
        audioPlayer?.rate = speed
    }
    
    // 音声再生位置の移動
    func changeLocation(seconds: Double) {
        guard let audioPlayer = self.audioPlayer else { return }
        
        let timeScale = CMTimeScale(NSEC_PER_SEC)
        let rhs = CMTime(seconds: seconds, preferredTimescale: timeScale)
        let time = CMTimeAdd(audioPlayer.currentTime(), rhs)
        audioPlayer.seek(to: time)
    }
    
    
}

