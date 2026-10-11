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
                .disabled(viewModel.isDeleting)
            }

            Section {
                Button("アカウントを削除", role: .destructive) {
                    isShowingDelete = true
                }
                .disabled(viewModel.isDeleting)
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
        .alert("操作を完了できませんでした", isPresented: Binding(
            get: { viewModel.operationError != nil },
            set: { if !$0 { viewModel.operationError = nil } }
        )) {
            Button("閉じる", role: .cancel) { viewModel.operationError = nil }
        } message: {
            Text(viewModel.operationError ?? "")
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

@MainActor
class AuthorizationDelegate: NSObject, ObservableObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    var onCompletion: ((Error?) -> Void)?
    private var currentNonce: String?
    private var deletingUser: User?
    private var authorizationController: ASAuthorizationController?
    private var window: UIWindow?

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        window ?? ASPresentationAnchor()
    }

    func deleteCurrentUser(_ user: User) {
        guard authorizationController == nil else { return }
        guard let window = SettingViewModel.presentationWindow else {
            onCompletion?(AccountOperationError.unavailable)
            return
        }
        self.window = window
        deletingUser = user
        let nonce = UUID().uuidString + UUID().uuidString
        currentNonce = nonce
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = SHA256.hash(data: Data(nonce.utf8)).map { String(format: "%02x", $0) }.joined()
        let controller = ASAuthorizationController(authorizationRequests: [request])
        authorizationController = controller
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8),
              let codeData = credential.authorizationCode,
              let code = String(data: codeData, encoding: .utf8),
              let user = deletingUser,
              Auth.auth().currentUser?.uid == user.uid else {
            finish(AccountOperationError.unavailable)
            return
        }
        currentNonce = nil
        Task {
            do {
                let firebaseCredential = OAuthProvider.appleCredential(withIDToken: token, rawNonce: nonce, fullName: nil)
                try await AccountDeletion.perform(reauthenticate: {
                    _ = try await user.reauthenticate(with: firebaseCredential)
                }, revoke: {
                    guard Auth.auth().currentUser?.uid == user.uid else { throw AccountOperationError.signedOut }
                    try await Auth.auth().revokeToken(withAuthorizationCode: code)
                }, delete: {
                    guard Auth.auth().currentUser?.uid == user.uid else { throw AccountOperationError.signedOut }
                    try await user.delete()
                })
                finish(nil)
            } catch {
                finish(error)
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if let error = error as? ASAuthorizationError, error.code == .canceled {
            finish(nil)
        } else {
            finish(error)
        }
    }

    private func finish(_ error: Error?) {
        currentNonce = nil
        deletingUser = nil
        authorizationController = nil
        window = nil
        onCompletion?(error)
    }
}
#Preview {
    NavigationStack {
        SettingView()
    }
}
