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

    @Published var isPresentingSearchMusic: Bool = true
    @Published var isPresentingSearch: Bool = true
    @Published var documentId = "default_value"
    @Published var isPresentingCamera: Bool = true
    @Published var showAlert = false
    private var cancellables: Set<AnyCancellable> = []
  
    
    func tapAction(trackName: String,Url: String) async throws{
        let db = Firestore.firestore()
        
        if let currentUser = Auth.auth().currentUser {
            let uid = currentUser.uid
           
            try await db.collection("users").document(uid).collection("photo").document(documentId).updateData([
                
                "trackName": trackName,
                "id": Url
                
            ])
           
          
            
        }
        DispatchQueue.main.async {
           
            print("firebaseに保存しました！,",self.documentId,self.isPresentingSearch)
          
           
        }
       
    }
    
}
