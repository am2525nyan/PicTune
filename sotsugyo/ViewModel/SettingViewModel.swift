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
import CryptoKit


class SettingViewModel: ObservableObject {
    @Published internal var showingPasswordAlert = false
    @Published internal var mailAddress = ""
    @Published internal var name = ""
    @Published var authorizationDelegate = AuthorizationDelegate()
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
            authorizationDelegate.onAppear()
            
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
            
        }
        if user.providerData.first(where: { $0.providerID == "password" }) != nil {
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
  
    func reauthenticateAndDeleteUser(_ user: User) {
            // nonceの生成
            let nonce = UUID().uuidString

            // Apple IDプロバイダーを取得
            let appleIDProvider = ASAuthorizationAppleIDProvider()

            // 認証リクエストの作成
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = authorizationDelegate.sha256(nonce)

            // 認証コントローラーの作成
            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            authorizationController.delegate = authorizationDelegate
            authorizationController.presentationContextProvider = authorizationDelegate

            // 認証リクエストの実行
            authorizationController.performRequests()
        }
    func sha256(_ input: String) -> String {
           let inputData = Data(input.utf8)
           let hashedData = SHA256.hash(data: inputData)
           let hashString = hashedData.compactMap {
               String(format: "%02x", $0)
           }.joined()

           return hashString
       }
}
