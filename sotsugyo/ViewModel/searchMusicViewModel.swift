//
//  searchMusicViewModel.swift
//  sotsugyo
//
//  Created by saki on 2023/11/29.
//

import Combine
import Foundation
import UIKit
import FirebaseAuth
import FirebaseFirestore

class SearchMusicViewModel: ObservableObject {
   
    @Published var musicList: [Music] = []
        @Published var artworks: [UIImage] = []
        @Published var searchText: String = ""
    @Published var isAlart: Bool = false
       @Published var isPresentingSearchMusic: Bool = true
   
   
    private var cancellables: Set<AnyCancellable> = []
    
    func tapAction(trackName: String,Url: String) async throws{
        let db = Firestore.firestore()
        
        if let currentUser = Auth.auth().currentUser {
            let uid = currentUser.uid
            try await db.collection("users").document(uid).collection("personal").document("info").updateData([
                "music": [
                    "trackName": trackName,
                    "previewUrl": Url
                ]
            ])
        }
        DispatchQueue.main.async {
           
            self.isAlart = true
            self.isPresentingSearchMusic = true
            
        }
    }
    func getImage(url: URL) async -> UIImage? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else { return nil }
            return image
        } catch {
            return nil
        }
    }
    
    func searchBarTextChanged() {
        let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            
            return
        }
        
        Task {
            let response: MusicResponse? = await requestMusic(keyword: text)
            guard let musicResult = response else {
                print("Failed to fetch music data")
                return
            }
            DispatchQueue.main.async {
                self.artworks = []
                
            }
            for music in musicResult.result {
                if let image = await getImage(url: music.artworkUrl60) {
                    DispatchQueue.main.async {
                        self.artworks.append(image)
                    }
                }
            }
            DispatchQueue.main.async {
                self.musicList = musicResult.result
            }
        }
    }
    
    func requestMusic(keyword: String) async -> MusicResponse? {
        let urlString = "https://itunes.apple.com/search?term=\(keyword)&entity=song&country=JP&lang=ja_jp&limit=20"
        guard let encodedUrlString = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        
        guard let url = URL(string: encodedUrlString) else {
            return nil
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }
            
            let decodedData = try JSONDecoder().decode(MusicResponse.self, from: data)
            return decodedData
        } catch {
            print(error)
            return nil
        }
    }
    
}
