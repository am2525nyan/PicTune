//
//  SettingView.swift
//  sotsugyo
//
//  Created by saki on 2024/01/09.
//
import SwiftUI
import FirebaseAuth
import GoogleSignIn
import FirebaseFirestore
import Firebase
import FirebaseAuthUI
import FirebaseGoogleAuthUI
import FirebaseOAuthUI
import FirebaseEmailAuthUI
import Foundation
import AuthenticationServices
import CryptoKit

struct SettingView: View {
    @State private var showingPasswordAlert = false
    @State private var password = ""
    let authorizationDelegate = AuthorizationDelegate()
    var body: some View {
        VStack {
            Button("またね") {
                do {
                    try Auth.auth().signOut()
                } catch let signOutError as NSError {
                    print("Error signing out: \(signOutError)")
                }
            }

            Button("Delete User") {
                deleteUser()
            }
            .alert("再認証", isPresented: $showingPasswordAlert) {
                SecureField("パスワード", text: $password)

                Button("キャンセル") {
                    // キャンセルボタンが押された場合の処理
                }
                Button("OK") {
                    reauthenticateWithPassword()
                }
            } message: {
                Text("パスワードを入力してください")
            }
            .environmentObject(authorizationDelegate)
        }
    }

    private func deleteUser() {
        guard let user = Auth.auth().currentUser else {
            // ユーザーがログインしていない場合の処理を追加
            return
        }

        // Appleログインの場合
        if let providerData = user.providerData.first(where: { $0.providerID == "apple.com" }) {
            reauthenticateUser(user)
        }

        // Googleログインの場合
        if let providerData = user.providerData.first(where: { $0.providerID == "google.com" }) {
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

    private func reauthenticateWithPassword() {
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

    private func reauthenticateUser(_ user: User) {
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

// ASAuthorizationControllerDelegateのメソッドを追加
class AuthorizationDelegate: NSObject, ObservableObject, ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential
        else {
            print("Unable to retrieve AppleIDCredential")
            return
        }

        // ここにASAuthorizationControllerDelegateのメソッドの実装を追加する

        guard let _ = currentNonce else {
            fatalError("Invalid state: A login callback was received, but no login request was sent.")
        }

        guard let appleAuthCode = appleIDCredential.authorizationCode else {
            print("Unable to fetch authorization code")
            return
        }

        guard let authCodeString = String(data: appleAuthCode, encoding: .utf8) else {
            print("Unable to serialize auth code string from data: \(appleAuthCode.debugDescription)")
            return
        }
        guard let user = Auth.auth().currentUser else {
            // ユーザーがログインしていない場合の処理を追加
            return
        }

        Task {
            do {
                // ここにAuth.auth().revokeTokenとuser?.delete()を実行する処理を追加する
                Auth.auth().revokeToken(withAuthorizationCode: authCodeString)
                user.delete()
            } catch {
               
            }
        }
    }

    // ここにASAuthorizationControllerDelegateの他のメソッドを追加する
}

// 未定義の関数や変数については、適切に実装する
func displayError(_ error: Error) {
    // エラー表示の処理を追加する
}

func updateUI() {
    // UIの更新処理を追加する
}

// CryptoUtilsとcurrentNonceの定義は適切に行う
var currentNonce: String?
