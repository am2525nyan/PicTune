//
//  AuthenticationManager.swift
//  sotsugyo
//
//  Created by saki on 2023/10/29.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

@Observable class AuthenticationManager {
    private(set) var isSignIn: Bool = false
    private var handle: AuthStateDidChangeListenerHandle!
    
    init() {
        // ここで認証状態の変化を監視する（リスナー）
        handle = Auth.auth().addStateDidChangeListener { (auth, user) in
            if let _ = user {
                
                self.isSignIn = true
               
            } else {
                print("Sign-out")
                self.isSignIn = false
               
            }
        }
    }
    
    deinit {
        // ここで認証状態の変化の監視を解除する
        Auth.auth().removeStateDidChangeListener(handle)
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            print("Error")
        }
    }
    func saveUserData(){
     
            let db = Firestore.firestore()
            
            if let currentUser = Auth.auth().currentUser {
                let uid = currentUser.uid
                db.collection("users").document(uid).collection("personal").document("info").setData([
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
