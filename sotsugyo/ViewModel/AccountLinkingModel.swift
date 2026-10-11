import AuthenticationServices
import CryptoKit
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import Security
import SwiftUI

enum AccountProvider: String, CaseIterable, Identifiable {
    case apple = "apple.com"
    case google = "google.com"
    case email = "password"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .apple: return "Apple"
        case .google: return "Google"
        case .email: return "メールアドレス"
        }
    }
}

/// Linking never signs out or signs into another Firebase user, including on conflicts.
@MainActor
final class AccountLinkingModel: ObservableObject {
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?
    private let auth: Auth
    private let userID: String?
    private var appleNonce: String?

    init(auth: Auth = Auth.auth()) {
        self.auth = auth
        userID = auth.currentUser?.uid
    }

    func linkEmail(email: String, password: String) async -> Bool {
        await link(credential: EmailAuthProvider.credential(
            withEmail: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password))
    }

    func linkGoogle() async -> Bool {
        guard !isWorking else { return false }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            guard let clientID = FirebaseApp.app()?.options.clientID,
                  let presenter = SettingViewModel.presentationController else {
                throw AccountOperationError.unavailable
            }
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            guard let token = result.user.idToken?.tokenString else { throw AccountOperationError.unavailable }
            let credential = GoogleAuthProvider.credential(withIDToken: token,
                                                           accessToken: result.user.accessToken.tokenString)
            try await performLink(credential)
            return true
        } catch {
            show(error)
            return false
        }
    }

    func prepareApple(_ request: ASAuthorizationAppleIDRequest) {
        errorMessage = nil
        // A fresh cryptographically random nonce for each authorization attempt.
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            appleNonce = nil
            errorMessage = "Appleとの連携を開始できませんでした。もう一度お試しください。"
            return
        }
        let nonce = bytes.map { String(format: "%02x", $0) }.joined()
        appleNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = SHA256.hash(data: Data(nonce.utf8)).map { String(format: "%02x", $0) }.joined()
        isWorking = true
    }

    func completeApple(_ result: Result<ASAuthorization, Error>) async -> Bool {
        defer { appleNonce = nil; isWorking = false }
        do {
            let authorization = try result.get()
            guard let apple = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = apple.identityToken,
                  let token = String(data: tokenData, encoding: .utf8),
                  let nonce = appleNonce else { throw AccountOperationError.unavailable }
            try await performLink(OAuthProvider.appleCredential(withIDToken: token, rawNonce: nonce,
                                                                fullName: apple.fullName))
            return true
        } catch {
            show(error)
            return false
        }
    }

    func link(credential: AuthCredential) async -> Bool {
        guard !isWorking else { return false }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await performLink(credential)
            return true
        } catch {
            show(error)
            return false
        }
    }

    private func performLink(_ credential: AuthCredential) async throws {
        guard let user = auth.currentUser, user.uid == userID else { throw AccountOperationError.signedOut }
        _ = try await user.link(with: credential)
        guard auth.currentUser?.uid == userID else { throw AccountOperationError.signedOut }
    }

    private func show(_ error: Error) {
        let nsError = error as NSError
        if (nsError.domain == ASAuthorizationError.errorDomain && nsError.code == ASAuthorizationError.canceled.rawValue)
            || (nsError.domain == kGIDSignInErrorDomain && nsError.code == GIDSignInError.canceled.rawValue) {
            return
        }
        errorMessage = Self.message(for: error)
    }

    static func message(for error: Error) -> String {
        let error = error as NSError
        guard error.domain == AuthErrorDomain else { return error.localizedDescription }
        switch AuthErrorCode.Code(rawValue: error.code) {
        case .credentialAlreadyInUse, .emailAlreadyInUse, .accountExistsWithDifferentCredential:
            return "この認証方法は、すでに別のアカウントで使われています。現在のデータはそのまま保持されています。既存のアカウントを使う場合は、設定の「既存のアカウントでログイン」から操作してください。"
        case .providerAlreadyLinked:
            return "この認証方法はすでに連携済みです。"
        case .invalidEmail:
            return "メールアドレスを確認してください。"
        case .weakPassword:
            return "パスワードが条件を満たしていません。より長く、複雑なパスワードを入力してください。"
        case .networkError:
            return "通信できませんでした。接続を確認して、もう一度お試しください。"
        default:
            return "連携できませんでした。もう一度お試しください。"
        }
    }
}
