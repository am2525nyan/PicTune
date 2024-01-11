//
//  ImagedetailView.swift
//  sotsugyo
//
//  Created by saki on 2024/01/11.
//

import Foundation
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore
import Photos

class ImageDetailViewModel: ObservableObject {
    func downloadFile(documentId: String, folderId: String) {
        let storage = Storage.storage()
        let storageRef = storage.reference()
        let db = Firestore.firestore()
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
}
