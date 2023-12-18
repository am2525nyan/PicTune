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
    
   
    @Published var artworks: [UIImage] = []
    @Published var searchText: String = ""

    @Published var isPresentingSearchMusic: Bool = true
    @Published var isPresentingSearch: Bool = true
    @Published var documentId = "default_value"
    @Published var isPresentingCamera: Bool = true
    @Published var showAlert = false
    private var cancellables: Set<AnyCancellable> = []
  
    
    func tapAction(trackName: String,Url: String,artistName: String, imageName: String, previewUrl: String,friendUid: String) async throws{
        let db = Firestore.firestore()
        
        if let currentUser = Auth.auth().currentUser {
            let uid = currentUser.uid
           
            try await db.collection("users").document(uid).collection("folders").document("all").collection("photos").document(documentId).updateData([
                "artistName": artistName,
                "trackName": trackName,
                "id": Url,
                "imageName": imageName,
                "previewUrl": previewUrl
                
            ])
        }
        try await db.collection("users").document(friendUid).collection("folders").document("all").collection("photos").document(documentId).updateData([
            "artistName": artistName,
            "trackName": trackName,
            "id": Url,
            "imageName": imageName,
            "previewUrl": previewUrl
            
        ])
        DispatchQueue.main.async {
           
            print("firebaseに保存しました！,",self.documentId,self.isPresentingSearch)
          
           
        }
       
    }
    
}
