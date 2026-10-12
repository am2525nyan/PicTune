import AuthenticationServices
import SwiftUI

struct AccountSettingsView: View {
    @ObservedObject var viewModel: SettingViewModel
    let onExistingLogin: () -> Void
    let onLinked: () -> Void
    @State private var isShowingExistingLogin = false

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
                            LabeledContent(provider.title, value: provider == .email ? "登録する" : "連携する")
                        }
                        .accessibilityLabel(provider == .email ? "メールアドレスを登録" : "\(provider.title)と連携する")
                        .accessibilityIdentifier("auth.connect.\(provider.rawValue)")
                    }
                }
            } header: {
                Text("ログイン方法")
            } footer: {
                Text("連携した方法で、機種変更後もログインできます。今の写真や手紙はそのまま残ります。")
            }

            Section {
                Button(viewModel.isAnonymous ? "ログイン" : "別のアカウントでログイン") {
                    isShowingExistingLogin = true
                }
                .accessibilityIdentifier("auth.openExistingLogin")
            } header: {
                Text(viewModel.isAnonymous ? "すでにアカウントをお持ちの方" : "アカウントの切り替え")
            }
        }
        .navigationTitle("アカウント")
        .navigationBarTitleDisplayMode(.inline)
        .alert("アカウントを切り替えますか？", isPresented: $isShowingExistingLogin) {
            Button("キャンセル", role: .cancel) {}
            Button("ログインへ進む") { onExistingLogin() }
        } message: {
            Text(viewModel.isAnonymous
                 ? "ログインすると、今の写真や手紙は引き継がれず、このアカウントには戻れなくなります。今のデータを残すには、ログイン方法を連携してください。"
                 : "ログインしたアカウントに切り替わります。今のアカウントのデータは引き継がれません。")
        }
    }
}

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
                    Button("登録する") {
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
                } footer: {
                    Text("Appleと連携すると、次回からAppleでログインできます。")
                }
            } else {
                Section {
                    Button("Googleで続ける") {
                        Task { finish(await model.linkGoogle()) }
                    }
                    .disabled(model.isWorking)
                    .accessibilityIdentifier("auth.linkGoogle")
                } footer: {
                    Text("Googleと連携すると、次回からGoogleでログインできます。")
                }
            }
            if model.isWorking {
                ProgressView("連携しています…")
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(provider == .email ? "メールアドレスを登録" : "\(provider.title)と連携")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(model.isWorking)
        .alert("連携できませんでした", isPresented: Binding(
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
