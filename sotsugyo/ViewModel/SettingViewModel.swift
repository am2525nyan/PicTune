//
//  SettingViewModel.swift
//  sotsugyo
//
//  Created by saki on 2024/01/11.
//

import Foundation
import FirebaseAuth
import AuthenticationServices
import FirebaseAuth
import GoogleSignIn
import FirebaseFirestore
import Firebase
import FirebaseAuthUI
import FirebaseGoogleAuthUI
import FirebaseOAuthUI
import FirebaseEmailAuthUI


class SettingViewModel: ObservableObject {
    @Published internal var showingPasswordAlert = false
    @Published internal var mailAddress = ""
    @Published internal var name = ""
    
    func getMail()async throws ->String {
        let db = Firestore.firestore()
        
        if let currentUser = Auth.auth().currentUser {
            let uid = currentUser.uid
            let document = try await db.collection("users").document(uid).collection("personal").document("info").getDocument()
            
            let data = document.data()
            let mail = data?["email"] as? String ?? ""
            self.mailAddress = mail
            
        }
        return mailAddress
    }
    func getName()async throws ->String {
        let db = Firestore.firestore()
        
        if let currentUser = Auth.auth().currentUser {
            let uid = currentUser.uid
            let document = try await db.collection("users").document(uid).collection("personal").document("info").getDocument()
            
            let data = document.data()
            let mail = data?["name"] as? String ?? ""
            self.name = mail
            
        }
        return name
    }
    func saveName(name: String){
        let db = Firestore.firestore()
        
        if let currentUser = Auth.auth().currentUser {
            let uid = currentUser.uid
            db.collection("users").document(uid).collection("personal").document("info").updateData(
                ["name" : name])
        }
    }
    
    func logout(){
        do {
            try Auth.auth().signOut()
        } catch let signOutError as NSError {
            print("Error signing out: \(signOutError)")
        }
    }
    func deleteUser() {
        guard let user = Auth.auth().currentUser else {
            // ユーザーがログインしていない場合の処理を追加
            return
        }
        
        // Appleログインの場合
        if user.providerData.first(where: { $0.providerID == "apple.com" }) != nil {
            reauthenticateUser(user)
        }
        
        // Googleログインの場合
        if user.providerData.first(where: { $0.providerID == "google.com" }) != nil {
            // 認証情報を作成する
            let credential = GoogleAuthProvider.credential(withIDToken: GIDSignIn.sharedInstance.currentUser!.authentication.idToken!, accessToken: GIDSignIn.sharedInstance.currentUser!.authentication.accessToken)
            
            // 再認証を実行する
            user.reauthenticate(with: credential, completion: { (authResult, error) in
                if let error = error {
                    // 再認証に失敗した場合
                    print(error)
                } else {
                    // 再認証に成功した場合
                    // ユーザーを削除する
                    user.delete(completion: { (error) in
                        if let error = error {
                            // 削除に失敗した場合
                            print(error)
                        } else {
                            // 削除成功の場合の処理を追加
                        }
                    })
                }
            })
            
        } else {
            // パスワード再認証のアラートを表示
            showingPasswordAlert = true
        }
    }
    
    func reauthenticateWithPassword(password: String) {
        guard let user = Auth.auth().currentUser else {
            // ユーザーがログインしていない場合の処理を追加
            return
        }
        
        let credential = EmailAuthProvider.credential(withEmail: user.email!, password: password)
        user.reauthenticate(with: credential) { (_, error) in
            if let error = error {
                print("Reauthentication with password failed: \(error.localizedDescription)")
                // 再認証エラーの処理を行う（例: エラーメッセージを表示）
            } else {
                // 再認証成功の場合、アカウント削除処理を実行
                user.delete { error in
                    if let error = error {
                        print("Delete user failed: \(error.localizedDescription)")
                        // 削除エラーの処理を行う（例: エラーメッセージを表示）
                    } else {
                        // 削除成功の場合の処理を追加
                        print("User deleted successfully")
                    }
                }
            }
        }
    }
    func reauthenticateUser(_ user: User) {
        let nonce = UUID().uuidString
        
        user.getIDToken { (token, error) in
            if let error = error {
                print("ID Tokenの取得に失敗しました: \(error.localizedDescription)")
            } else if let token = token {
                // 認証情報を作成する
                let credential = OAuthProvider.credential(withProviderID: "apple.com", idToken: token, rawNonce: nonce)
                
                // 再認証を実行する
                user.reauthenticate(with: credential) { (_, error) in
                    if let error = error {
                        // 再認証に失敗した場合
                        print("Reauthentication failed: \(error.localizedDescription)")
                    } else {
                        // ユーザーを削除する
                        user.delete { error in
                            if let error = error {
                                // 削除に失敗した場合
                                print("Delete user failed: \(error.localizedDescription)")
                            } else {
                                // 削除成功の場合の処理を追加
                                print("User deleted successfully")
                            }
                        }
                    }
                }
            }
        }
    }
    
    
    
}
