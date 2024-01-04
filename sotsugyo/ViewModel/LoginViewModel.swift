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
        
        // デリゲートを設定
        authUI.delegate = context.coordinator
        
        return authViewController
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        // 処理なし
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    class Coordinator: NSObject, FUIAuthDelegate {
        var viewModel: MainContentModel

        init(viewModel: MainContentModel) {
            self.viewModel = viewModel
        }

        // サインイン成功時の処理
        func authUI(_ authUI: FUIAuth, didSignInWith user: User?, error: Error?) {
            if let error = error {
                print("Sign-in error: \(error.localizedDescription)")
            } else {
                // サインイン成功時の処理
                viewModel.saveUserData()
            }
        }
    }
}
