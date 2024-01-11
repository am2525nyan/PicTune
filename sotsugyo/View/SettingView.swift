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
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SettingViewModel()
    @StateObject private var color = ColorModel()
    let authorizationDelegate = AuthorizationDelegate()
    
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
    
    class AuthorizationDelegate: NSObject, ObservableObject, ASAuthorizationControllerDelegate {
        var currentNonce: String?
        
        func authorizationController(controller: ASAuthorizationController,
                                     didCompleteWithAuthorization authorization: ASAuthorization) {
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential
            else {
                print("Unable to retrieve AppleIDCredential")
                return
            }
            
            
            
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
                do{
                    Auth.auth().revokeToken(withAuthorizationCode: authCodeString)
                    user.delete()
                } catch {
                    
                }
            }
        }
        
    }
    
    // 未定義の関数や変数については、適切に実装する
    func displayError(_ error: Error) {
        // エラー表示の処理を追加する
    }
    
    func updateUI() {
        // UIの更新処理を追加する
    }
    
}

