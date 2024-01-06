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
   
    
}
