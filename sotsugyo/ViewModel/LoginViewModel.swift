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
                if let user = user {
                    self?.viewModel.saveUserData()
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
