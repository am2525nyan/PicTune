//
//  searchMusicViewModel.swift
//  sotsugyo
//
//  Created by saki on 2023/11/29.
//



import Combine
import Foundation
import FirebaseAuth
import FirebaseFirestore

class SearchViewModel: ObservableObject {
    
    @Published var musicList: [Music] = []
    @Published var artworks: [UIImage] = []
    @Published var searchText: String = ""
    @Published var isAlart: Bool = false
    @Published var isPresentingSearchMusic: Bool = true
    @Published var isPresentingSearch: Bool = true
    @Published var documentId = "default_value"
    @Published var isPresentingCamera: Bool = true
    private var cancellables: Set<AnyCancellable> = []
    
    func tapAction(trackName: String,Url: String) async throws{
        let db = Firestore.firestore()
        
        if let currentUser = Auth.auth().currentUser {
            let uid = currentUser.uid
           
            try await db.collection("users").document(uid).collection("photo").document(documentId).updateData([
                
                "trackName": trackName,
                "previewUrl": Url
                
            ])
            print(documentId)
            DispatchQueue.main.async {
                self.isPresentingSearch = false
                self.isPresentingCamera = false
            }
        }
        DispatchQueue.main.async {
            self.isAlart = true
            
        }
    }
    
}
