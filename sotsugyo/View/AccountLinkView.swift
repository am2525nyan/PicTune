import AuthenticationServices
import SwiftUI

struct AccountSettingsView: View {
    @ObservedObject var viewModel: SettingViewModel
    let onLinked: () -> Void

    var body: some View {
        Form {
            Section {
                LabeledContent("利用状況", value: viewModel.isAnonymous ? "未ログイン" : "ログイン済み")
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("auth.accountStatus")
            }

            Section {
                ForEach(AccountProvider.allCases) { provider in
                    if viewModel.linkedProviderIDs.contains(provider.rawValue) {
                        HStack {
                            Text(provider.title)
                            Spacer()
                            Label(provider == .email ? "登録済み" : "連携済み", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("auth.linked.\(provider.rawValue)")
                    } else {
                        NavigationLink {
                            AccountLinkView(provider: provider, onLinked: onLinked)
                        } label: {
                            LabeledContent(provider.title, value: "続ける")
                        }
                        .accessibilityLabel("\(provider.title)で続ける")
                        .accessibilityIdentifier("auth.connect.\(provider.rawValue)")
                    }
                }
            } header: {
                Text("ログイン方法")
            } footer: {
                Text("初めての場合は、今の写真や手紙を引き継いで登録します。登録済みの場合は、そのアカウントにログインできます。")
            }
        }
        .navigationTitle("アカウント")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AccountLinkView: View {
    let provider: AccountProvider
    let onLinked: () -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = AccountLinkingModel()
    @State private var email = ""
    @State private var password = ""
    @State private var isShowingExistingSignIn = false
    @State private var isShowingPasswordReset = false
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    private var canLinkEmail: Bool {
        !model.isWorking && !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !password.isEmpty
    }

    var body: some View {
        Form {
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
                        SecureField("パスワードを入力", text: $password)
                            .textContentType(.password)
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
                    Button("メールアドレスで続ける") {
                        focusedField = nil
                        Task { finish(await model.linkEmail(email: email, password: password)) }
                    }
                    .accessibilityIdentifier("auth.linkEmail")
                    .disabled(!canLinkEmail)
                } footer: {
                    Text("初めての場合は、6文字以上のパスワードを設定してください。登録済みの場合は、いつものパスワードを入力してください。")
                }
                Section {
                    Button("パスワードをお忘れですか？") {
                        focusedField = nil
                        Task { isShowingPasswordReset = await model.sendPasswordReset(email: email) }
                    }
                    .disabled(model.isWorking || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("auth.resetPassword")
                }
            } else if provider == .apple {
                Section {
                    SignInWithAppleButton(.continue, onRequest: model.prepareApple) { result in
                        Task { finish(await model.completeApple(result)) }
                    }
                    .frame(height: 48)
                    .disabled(model.isWorking)
                    .accessibilityIdentifier("auth.linkApple")
                } footer: {
                    Text("初めて使うAppleアカウントは、今の写真や手紙に紐づけます。登録済みなら、そのアカウントにログインします。")
                }
            } else {
                Section {
                    Button("Googleで続ける") {
                        Task { finish(await model.linkGoogle()) }
                    }
                    .disabled(model.isWorking)
                    .accessibilityIdentifier("auth.linkGoogle")
                } footer: {
                    Text("初めて使うGoogleアカウントは、今の写真や手紙に紐づけます。登録済みなら、そのアカウントにログインします。")
                }
            }
            if model.isWorking {
                ProgressView("認証しています…")
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("\(provider.title)で続ける")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(model.isWorking)
        .onChange(of: model.hasPendingSignIn) { _, pending in
            isShowingExistingSignIn = pending
        }
        .onDisappear { model.cancelExistingSignIn() }
        .alert("メールをご確認ください", isPresented: $isShowingPasswordReset) {
            Button("閉じる", role: .cancel) {}
        } message: {
            Text("パスワードを再設定するためのメールを送信しました。届かない場合は、入力したメールアドレスと迷惑メールをご確認ください。")
        }
        .alert("登録済みのアカウントにログインしますか？", isPresented: $isShowingExistingSignIn) {
            Button("キャンセル", role: .cancel) { model.cancelExistingSignIn() }
            Button("ログイン") {
                Task {
                    if await model.confirmExistingSignIn() {
                        password = ""
                        dismiss()
                    }
                }
            }
        } message: {
            Text(model.isAnonymous
                 ? "今の写真や手紙は引き継がれず、このアカウントには戻れなくなります。"
                 : "ログインしたアカウントに切り替わります。今の写真や手紙は、そのアカウントには引き継がれません。")
        }
        .alert("認証できませんでした", isPresented: Binding(
            get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("閉じる", role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }

    private func finish(_ success: Bool) {
        guard success else { return }
        password = ""
        onLinked()
        dismiss()
    }
}
