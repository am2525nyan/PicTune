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
    @State private var isSaveName = false
    @State private var islogout = false
    @State private var isdelete = false
    @State private var password = ""
    @State private var name = ""
    @State private var mailAddress = ""
    @State  var currentNonce = ""
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SettingViewModel()
    @StateObject private var color = ColorModel()
    @StateObject private var authorizationDelegate = AuthorizationDelegate()
    
    var body: some View {
        NavigationView{
            
            VStack {
                VStack(alignment: .leading) {
                    Text("Name")
                        .font(.custom("Roboto", size: 20))
                        .foregroundColor(Color(red: 0, green: 0, blue: 0))
                        .padding(.top,70)
                    
                    TextField("名前を入力", text: $name)
                        .font(.custom("Roboto", size: 25))
                        .padding(5)
                        .border(.gray, width: 0.5)
                        .padding(.trailing, 30)
                    
                    Text("メールアドレス")
                        .font(.custom("Roboto", size: 20))
                        .foregroundColor(Color(red: 0, green: 0, blue: 0))
                    Text(mailAddress)
                        .font(.custom("Roboto", size: 25))
                        .foregroundColor(Color(red: 0, green: 0, blue: 0))
                    Spacer()
                }
                .padding(.leading,30)
                Button(action: {
                    isSaveName.toggle()
                }, label: {
                    Text("保存")
                        .foregroundColor(.white)
                        .font(.custom("Roboto", size: 30))
                        .padding(5)
                        .padding(.horizontal, 60)
                        .background(Color(red: 0.741, green: 0.584, blue: 0.933))
                    
                })
                .padding(.top,30)
                .alert("保存", isPresented: $isSaveName) {
                    
                    Button("cancel",role: .cancel) {
                        
                    }
                    Button("OK") {
                        viewModel.saveName(name: name)
                    }
                } message: {
                    Text("保存しますか？")
                }
                
                
                
                Button {
                    islogout.toggle()
                } label: {
                    Text("ログアウト")
                }
                .padding(10)
                .alert("ログアウト", isPresented: $islogout) {
                    
                    
                    Button("OK",role: .destructive) {
                        viewModel.logout()
                    }
                } message: {
                    Text("本当にログアウトしますか？")
                }
                
                
                
                Button("アカウント削除") {
                    isdelete.toggle()
                    
                }
                .foregroundColor(.red)
                .padding(.bottom, 30)
                .alert("削除", isPresented: $isdelete) {
                    
                    
                    Button("OK",role: .destructive) {
                        viewModel.deleteUser()
                    }
                } message: {
                    Text("本当にアカウントを削除しますか？")
                }
                .alert("再認証", isPresented: $viewModel.showingPasswordAlert) {
                    SecureField("パスワード", text: $password)
                    
                    
                    Button("OK", role: .destructive) {
                        viewModel.reauthenticateWithPassword(password: password)
                    }
                } message: {
                    Text("パスワードを入力してください")
                }
                .environmentObject(authorizationDelegate)
            }
            .onAppear{
                Task{
                    do{
                        mailAddress = try await viewModel.getMail()
                        name = try await viewModel.getName()
                    }catch{
                        
                    }
                }
              
                
                
            }
            .environmentObject(authorizationDelegate)
            .navigationBarItems(leading: Button(action: {
                dismiss()
                
            }) {
                Image(systemName: "arrow.left")
            })
            .navigationTitle("Setting")
            .toolbarBackground(color.backGroundColor2(), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
    
    
    
}



class AuthorizationDelegate: NSObject, ObservableObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
      
        return ASPresentationAnchor()
    }
    
    var currentNonce: String?
    
    func onAppear() {
        let nonce = randomNonceString()
        currentNonce = nonce
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    func deleteCurrentUser() {
        do {
            let nonce = randomNonceString()
            currentNonce = nonce
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = sha256(nonce)
            
            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            authorizationController.delegate = self
            authorizationController.presentationContextProvider = self
            authorizationController.performRequests()
        } catch {
           print(error)
            
        }
    }
    func reauthenticateUser(_ user: User, appleIdToken: String, rawNonce: String) {
        let nonce = UUID().uuidString

        let credential = OAuthProvider.credential(
               withProviderID: "apple.com",
               idToken: appleIdToken,
               rawNonce: rawNonce
           )
           
           // Reauthenticate current Apple user with fresh Apple credential.
           user.reauthenticate(with: credential) { (authResult, error) in
               if let error = error {
                   // 再認証に失敗した場合
                   print("Reauthentication failed: \(error.localizedDescription)")
               } else {
                   // Appleユーザーが成功裏に再認証された場合
                   // authResultを使用して必要な処理を追加することもできます
                   print("Apple user successfully re-authenticated.")
               }
           }
    }

    func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError(
                "Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)"
            )
        }
        
        let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        
        let nonce = randomBytes.map { byte in
            // Pick a random character from the set, wrapping around if needed.
            charset[Int(byte) % charset.count]
        }
        
        return String(nonce)
    }
    
    func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
    
    
    
    
    
    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential
        else {
            print("Unable to retrieve AppleIDCredential")
            return
        }
        
        guard currentNonce != nil else {
            // currentNonceがnilの場合の処理
            return
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
        if let appleIdToken = String(data: appleIDCredential.identityToken!, encoding: .utf8) {
               // appleIdToken を使用して再認証などの処理を行う
            reauthenticateUser(user, appleIdToken: appleIdToken, rawNonce: currentNonce!)
           } else {
               print("Unable to fetch Apple ID Token")
           }
        Task {
            do {
                // ここにAuth.auth().revokeTokenとuser?.delete()を実行する処理を追加する
                try await Auth.auth().revokeToken(withAuthorizationCode: authCodeString)
             
              try await user.delete()
            } catch {
                // エラーの処理を追加
                print("Error deleting user: \(error.localizedDescription)")
            }
        }
    }
    
}
