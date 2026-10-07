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

@MainActor
class CameraMusicViewModel: ObservableObject {
    var audioPlayer: AVPlayer?
    var url: URL?
    
    func getMusic()async throws{
        url = nil
        let db = Firestore.firestore()
        if let currentUser = Auth.auth().currentUser {
            let uid = currentUser.uid
            let document = try await db.collection("users").document(uid).collection("personal").document("info").getDocument()
            let data = document.data()
            guard let musicUrl = data?["previewUrl"] as? String,
                  let previewURL = URL(string: musicUrl),
                  ["https", "http"].contains(previewURL.scheme?.lowercased() ?? ""),
                  previewURL.host != nil else { return }
            url = previewURL
        }
    }
    
   
}
