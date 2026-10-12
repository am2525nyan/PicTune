import AuthenticationServices
import SwiftUI

struct AccountLinkView: View {
    let provider: AccountProvider
    let onLinked: () -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = AccountLinkingModel()
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    private var canLinkEmail: Bool {
        !model.isWorking && !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && password.count >= 6
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("今の思い出を引き継ぐ")
                            .font(.headline)
                        Text("\(provider.title)を使って、今のアカウントにログインできるようにします。写真・フォルダ・手紙はそのまま残ります。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                if provider == .email {
                    Section("ログイン情報") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("メールアドレス").font(.caption).foregroundStyle(.secondary)
                            TextField("メールアドレスを入力", text: $email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .email)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .password }
                                .accessibilityLabel("メールアドレス")
                                .accessibilityIdentifier("auth.email")
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("パスワード").font(.caption).foregroundStyle(.secondary)
                            SecureField("6文字以上で入力", text: $password)
                                .textContentType(.newPassword)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .password)
                                .submitLabel(.done)
                                .onSubmit { focusedField = nil }
                                .accessibilityLabel("パスワード")
                                .accessibilityIdentifier("auth.password")
                        }
                    }
                    .disabled(model.isWorking)
                    Section {
                        Button("メールアドレスを連携") {
                            focusedField = nil
                            Task { finish(await model.linkEmail(email: email, password: password)) }
                        }
                        .accessibilityIdentifier("auth.linkEmail")
                        .disabled(!canLinkEmail)
                    } footer: {
                        Text("次回から、このメールアドレスとパスワードでログインできます。")
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
            .scrollDismissesKeyboard(.interactively)
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
        onLinked()
        dismiss()
    }
}
