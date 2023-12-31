//
//  CameraMusicViewModel.swift
//  sotsugyo
//
//  Created by saki on 2023/11/29.
//

import Foundation
import AVFoundation
import FirebaseFirestore
import FirebaseAuth

class CameraMusicViewModel: ObservableObject {
    var audioPlayer: AVPlayer?
    var url = URL.init(string: "https://www.hello.com/sample.wav")
    
    func getMusic()async throws{
        let db = Firestore.firestore()
        if let currentUser = Auth.auth().currentUser {
            let uid = currentUser.uid
            let document = try await db.collection("users").document(uid).collection("personal").document("info").getDocument()
            let data = document.data()
            let musicUrl = data?["previewUrl"] as! String
            url =  URL.init(string: musicUrl )
        }
    }
    
    func startPlay() {
        let sampleUrl = URL.init(string: "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview115/v4/8f/c1/32/8fc1329a-bf7d-03f2-3082-6536f60666ee/mzaf_1239907852510333018.plus.aac.p.m4a")
        audioPlayer = AVPlayer.init(playerItem: AVPlayerItem(url: url ?? sampleUrl! ))
        audioPlayer?.play()
    }
    
    
    func stop() {
        audioPlayer?.pause()
    }
}
