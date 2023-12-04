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

class MainContentModel: ObservableObject {
  
    
    @Published internal var isShowSheet = false
    @Published internal var images: [UIImage] = []
    @Published internal var isPresentingCamera = false
    
    
   
    func firstgetUrl() async throws{
        do{
            guard let uid = Auth.auth().currentUser?.uid else {
                throw NSError(domain: "FirebaseError", code: -1, userInfo: [NSLocalizedDescriptionKey: "uid is nil"])
            }
            
            let db = Firestore.firestore()
            
            var urlArray = [String]()
            DispatchQueue.main.async {
                self.images = []
                   }
          
            
            let ref = try await db.collection("users").document(uid).collection("photo").getDocuments()
            
            for document in ref.documents {
                
                let data = document.data()
                let url = data["url"]
                if url != nil{
                    urlArray.append(url as! String)
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
                let ref = try await db.collection("users").document(uid ?? "").collection("photo").whereField("date", isGreaterThanOrEqualTo: date as Any).getDocuments()
                
                for document in ref.documents {
                    
                    let data = document.data()
                    let url = data["url"]
                    if url != nil{
                        urlArray.append(url as! String)
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
    
    
    
}
