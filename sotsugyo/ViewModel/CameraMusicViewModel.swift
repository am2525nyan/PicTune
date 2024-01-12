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
    
   
}
