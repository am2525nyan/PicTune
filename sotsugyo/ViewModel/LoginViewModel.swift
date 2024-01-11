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
    @StateObject var viewModel: MainContentModel
    
    func makeUIViewController(context: Context) -> UIViewController {
        let authUI = FUIAuth.defaultAuthUI()
        guard authUI != nil else {
            return UIViewController()
        }
        
        // サポートするログイン方法を構成
        let providers: [FUIAuthProvider] = [
            FUIGoogleAuth(authUI: authUI!),
            FUIOAuth.appleAuthProvider(),
            FUIEmailAuth()
        ]
        authUI!.providers = providers
        
        
        
        // FirebaseUIを表示する
        let authViewController = authUI!.authViewController()
        
        
        // デリゲートを設定
        authUI!.delegate = context.coordinator
        context.coordinator.startListening()
        return authViewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        // 処理なし
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }
    
    class Coordinator: NSObject, FUIAuthDelegate {
        var viewModel: MainContentModel
        var handle: AuthStateDidChangeListenerHandle?
        
        init(viewModel: MainContentModel) {
            self.viewModel = viewModel
        }
        
        
        func startListening() {
            handle = Auth.auth().addStateDidChangeListener { [weak self] (_, user) in
                if user != nil {
                    Task{
                        do{
                            try await self?.saveUserData()
                        }
                        catch{
                            print(error)
                        }
                    }
                    
                    
                }
            }
        }
        func saveUserData()async throws{
            
            let db = Firestore.firestore()
            
            if let currentUser = Auth.auth().currentUser {
                let uid = currentUser.uid
                Task{
                    do{
                        try await      db.collection("users").document(uid).collection("folders").document("all").setData(["title": "all","date": FieldValue.serverTimestamp()])
                    }
                }
                try await db.collection("users").document(uid).collection("personal").document("info").setData([
                    "uid": uid ,
                    "email": currentUser.email ?? "",
                    "name": currentUser.displayName
                ])
                Task{
                    
                    
                }
            }
            print("データがFirestoreに保存されましたよ")
            
            
        }
        
        func reauthenticateUser(_ user: User) {
            Auth.auth().addStateDidChangeListener { (auth, user) in
                if let user = user {
                    user.getIDToken { (token, error) in
                        if let error = error {
                            print("ID Tokenの取得に失敗しました: \(error.localizedDescription)")
                        } else if let token = token {
                            
                            let db = Firestore.firestore()
                            
                            if let currentUser = Auth.auth().currentUser {
                                let uid = currentUser.uid
                                db.collection("users").document(uid).collection("personal").document("info").updateData([
                                    "token": token
                                ]) { error in
                                    if let error = error {
                                        print("データの保存に失敗しました: \(error.localizedDescription)")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        func stopListening() {
            if let handle = handle {
                Auth.auth().removeStateDidChangeListener(handle)
            }
        }
        
    }
    
}
