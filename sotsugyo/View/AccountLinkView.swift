import AuthenticationServices
import SwiftUI

struct AccountLinkView: View {
    let provider: AccountProvider
    let onLinked: () -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = AccountLinkingModel()
    @State private var email = ""
    @State private var password = ""
    @State private var passwordConfirmation = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("現在のアカウントに\(provider.title)を連携します。写真・フォルダ・手紙を引き継ぎ、連携した方法で別の端末からもログインできます。")
                }
                if provider == .email {
                    Section("ログイン情報") {
                        TextField("メールアドレス", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .accessibilityIdentifier("auth.email")
                        SecureField("パスワード", text: $password)
                            .textContentType(.newPassword)
                            .accessibilityIdentifier("auth.password")
                        SecureField("パスワード（確認）", text: $passwordConfirmation)
                            .textContentType(.newPassword)
                            .accessibilityIdentifier("auth.passwordConfirmation")
                    }
                    .disabled(model.isWorking)
                    Section {
                        Button("メールアドレスを連携") {
                            Task { finish(await model.linkEmail(email: email, password: password)) }
                        }
                        .accessibilityIdentifier("auth.linkEmail")
                        .disabled(model.isWorking || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                  || password.isEmpty || password != passwordConfirmation)
                    } footer: {
                        Text("パスワードは6文字以上で入力してください。")
                    }
                } else if provider == .apple {
                    Section {
                        SignInWithAppleButton(.continue, onRequest: model.prepareApple) { result in
                            Task { finish(await model.completeApple(result)) }
                        }
                        .frame(height: 48)
                        .disabled(model.isWorking)
                        .accessibilityIdentifier("auth.linkApple")
                    }
                } else {
                    Section {
                        Button("Googleで続ける") {
                            Task { finish(await model.linkGoogle()) }
                        }
                        .disabled(model.isWorking)
                        .accessibilityIdentifier("auth.linkGoogle")
                    }
                }
                if model.isWorking {
                    ProgressView("連携しています…")
                }
            }
            .navigationTitle("\(provider.title)を連携")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                        .disabled(model.isWorking)
                }
            }
            .alert("連携できませんでした", isPresented: Binding(
                get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } }
            )) {
                Button("閉じる", role: .cancel) { model.errorMessage = nil }
            } message: { Text(model.errorMessage ?? "") }
            .interactiveDismissDisabled(model.isWorking)
        }
    }

    private func finish(_ success: Bool) {
        guard success else { return }
        password = ""
        passwordConfirmation = ""
        onLinked()
        dismiss()
    }
}
