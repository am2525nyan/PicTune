//
//  loginView.swift
//  sotsugyo
//
//  Created by saki on 2023/10/29.
//

import SwiftUI
import Firebase
import FirebaseAuthUI
import FirebaseGoogleAuthUI
import FirebaseOAuthUI
import FirebaseEmailAuthUI
import FirebaseFirestore

struct LoginView: UIViewControllerRepresentable {
    
    func makeUIViewController(context: Context) -> UINavigationController {
        let authUI = FUIAuth.defaultAuthUI()!
        // サポートするログイン方法を構成
        let providers: [FUIAuthProvider] = [
            FUIGoogleAuth(authUI: authUI),
            FUIOAuth.appleAuthProvider(),
            FUIEmailAuth()
        ]
        authUI.providers = providers
        
        // FirebaseUIを表示する
        let authViewController = authUI.authViewController()
        
        return authViewController
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        // 処理なし
    }
    func authUI(_ authUI: FUIAuth, didSignInWith authDataResult: AuthDataResult?, error: Error?) {
        // Check if there was an error
        if let user = authDataResult?.user {
            let email = user.email
            let name = user.displayName
          
            Task{
                do{
                    
        
                       
                        try await self.saveUserData(email: email, name: name)
                        print("新規登録成功！")
                        
                    
                
                }catch{
                    print(error)
                }
            }
        }
        if let error = error {
            print("Error signing in: \(error.localizedDescription)")
            return
            
        }
    }
    func saveUserData(email: String?, name: String?)async throws {
        let db = Firestore.firestore()
        let uid = Auth.auth().currentUser?.uid
        print("uid！")
        try await db.collection("users").document(uid ?? "").collection("personal").document("info").setData([
            "uid": uid ?? "uid:Error",
            "email": email ?? "email:Error",
            "name": name ?? "name:Error",
        ])
      
     
    }
}


