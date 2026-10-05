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
    @StateObject private var viewModel: SettingViewModel
    @State private var isEditingName = false
    @State private var isShowingLogout = false
    @State private var isShowingDelete = false
    @State private var password = ""
    @State private var isLoading = false
    @State private var hasLoadedProfile = false
    @State private var profileError: String?

    init(viewModel: SettingViewModel? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel ?? SettingViewModel())
        _hasLoadedProfile = State(initialValue: viewModel != nil)
    }

    var body: some View {
        Form {
            Section("プロフィール") {
                if hasLoadedProfile {
                    Button {
                        isEditingName = true
                    } label: {
                        HStack(spacing: 16) {
                            LabeledContent("名前", value: viewModel.name.isEmpty ? "未設定" : viewModel.name)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("名前を編集します")
                    .popoverTip(SettingTip())
                }

                if isLoading {
                    ProgressView("読み込み中…")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                } else if let profileError {
                    Text(profileError)
                        .foregroundStyle(.secondary)
                    Button("再読み込み") {
                        Task { await loadProfile() }
                    }
                }
            }

            if hasLoadedProfile {
                Section {
                    Text(viewModel.mailAddress.isEmpty ? "未登録" : viewModel.mailAddress)
                        .textSelection(.enabled)
                } header: {
                    Text("メールアドレス")
                } footer: {
                    Text("メールアドレスはこのアプリでは変更できません。")
                }
            }

            Section {
                Button("ログアウト") {
                    isShowingLogout = true
                }
            }

            Section {
                Button("アカウントを削除", role: .destructive) {
                    isShowingDelete = true
                }
            } footer: {
                Text("アカウントを削除すると、元に戻すことはできません。")
            }
        }
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.large)
        .task {
            if !hasLoadedProfile {
                await loadProfile()
            }
        }
        .sheet(isPresented: $isEditingName) {
            NameEditView(name: viewModel.name) { name in
                try await viewModel.saveName(name: name)
            }
        }
        .alert("ログアウトしますか？", isPresented: $isShowingLogout) {
            Button("キャンセル", role: .cancel) {}
            Button("ログアウト") {
                viewModel.logout()
            }
        }
        .alert("アカウントを削除しますか？", isPresented: $isShowingDelete) {
            Button("キャンセル", role: .cancel) {}
            Button("削除", role: .destructive) {
                viewModel.deleteUser()
            }
        } message: {
            Text("この操作は取り消せません。")
        }
        .alert("再認証が必要です", isPresented: $viewModel.showingPasswordAlert) {
            SecureField("パスワード", text: $password)
            Button("キャンセル", role: .cancel) {
                password = ""
            }
            Button("認証して削除", role: .destructive) {
                viewModel.reauthenticateWithPassword(password: password)
                password = ""
            }
            .disabled(password.isEmpty)
        } message: {
            Text("アカウントを削除するには、パスワードを入力してください。")
        }
    }

    @MainActor
    private func loadProfile() async {
        guard !isLoading else { return }
        isLoading = true
        profileError = nil
        defer { isLoading = false }

        do {
            try await viewModel.loadProfile()
            hasLoadedProfile = true
        } catch {
            profileError = "プロフィールを読み込めませんでした。もう一度お試しください。"
        }
    }
}

private struct NameEditView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isNameFocused: Bool
    @State private var draftName: String
    @State private var isSaving = false
    @State private var isShowingSaveError = false
    @State private var isShowingDiscard = false

    private let originalName: String
    private let save: (String) async throws -> Void

    init(name: String, save: @escaping (String) async throws -> Void) {
        originalName = name
        _draftName = State(initialValue: name)
        self.save = save
    }

    private var trimmedName: String {
        draftName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasChanges: Bool {
        draftName != originalName
    }

    private var canSave: Bool {
        !isSaving && !trimmedName.isEmpty && trimmedName != originalName
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("名前") {
                    TextField("名前を入力", text: $draftName)
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .accessibilityLabel("名前")
                        .focused($isNameFocused)
                        .submitLabel(.done)
                        .disabled(isSaving)
                        .onSubmit {
                            if canSave {
                                Task { await saveName() }
                            }
                        }
                }

                if isSaving {
                    Section {
                        ProgressView("保存中…")
                    }
                }
            }
            .navigationTitle("名前を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        if hasChanges {
                            isNameFocused = false
                            isShowingDiscard = true
                        } else {
                            dismiss()
                        }
                    }
                    .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task { await saveName() }
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
            .confirmationDialog("変更を破棄しますか？", isPresented: $isShowingDiscard, titleVisibility: .visible) {
                Button("変更を破棄", role: .destructive) {
                    dismiss()
                }
                Button("編集を続ける", role: .cancel) {
                    isNameFocused = true
                }
            }
            .alert("名前を保存できませんでした", isPresented: $isShowingSaveError) {
                Button("閉じる", role: .cancel) {}
            } message: {
                Text("入力内容は保持されています。もう一度保存してください。")
            }
            .task {
                isNameFocused = true
            }
        }
        .interactiveDismissDisabled(hasChanges || isSaving)
    }

    @MainActor
    private func saveName() async {
        guard canSave else { return }
        isSaving = true
        isNameFocused = false
        defer { isSaving = false }

        do {
            try await save(trimmedName)
            dismiss()
        } catch {
            isShowingSaveError = true
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
        let credential = OAuthProvider.appleCredential(
            withIDToken: appleIdToken,
            rawNonce: rawNonce,
            fullName: nil
        )
        
        // Reauthenticate current Apple user with fresh Apple credential.
        user.reauthenticate(with: credential) { (authResult, error) in
            if let error = error {
                // 再認証に失敗した場合
                print("Reauthentication failed: \(error.localizedDescription)")
            } else {
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
#Preview {
    NavigationStack {
        SettingView()
    }
}
