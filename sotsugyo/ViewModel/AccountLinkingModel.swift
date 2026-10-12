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

/// Keep the current user until linking succeeds or an existing-account switch is confirmed.
@MainActor
final class AccountLinkingModel: ObservableObject {
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?
    @Published private(set) var hasPendingSignIn = false
    let isAnonymous: Bool
    private let auth: Auth
    private let userID: String?
    private var appleNonce: String?
    private var pendingCredential: AuthCredential?

    init(auth: Auth = Auth.auth()) {
        self.auth = auth
        userID = auth.currentUser?.uid
        isAnonymous = auth.currentUser?.isAnonymous ?? false
    }

    func linkEmail(email: String, password: String) async -> Bool {
        await link(credential: EmailAuthProvider.credential(
            withEmail: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password))
    }

    func linkGoogle() async -> Bool {
        guard !isWorking, !hasPendingSignIn else { return false }
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
            return try await performLink(credential)
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
            return try await performLink(OAuthProvider.appleCredential(withIDToken: token, rawNonce: nonce,
                                                                fullName: apple.fullName))
        } catch {
            show(error)
            return false
        }
    }

    func link(credential: AuthCredential) async -> Bool {
        guard !isWorking, !hasPendingSignIn else { return false }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            return try await performLink(credential)
        } catch {
            show(error)
            return false
        }
    }

    private func performLink(_ credential: AuthCredential) async throws -> Bool {
        guard let user = auth.currentUser, user.uid == userID else { throw AccountOperationError.signedOut }
        do {
            _ = try await user.link(with: credential)
        } catch {
            guard auth.currentUser?.uid == userID else { throw AccountOperationError.signedOut }
            guard let credential = Self.existingSignInCredential(for: error, original: credential) else {
                throw error
            }
            pendingCredential = credential
            hasPendingSignIn = true
            return false
        }
        guard auth.currentUser?.uid == userID else { throw AccountOperationError.signedOut }
        return true
    }

    static func existingSignInCredential(for error: Error, original: AuthCredential) -> AuthCredential? {
        let error = error as NSError
        guard error.domain == AuthErrorDomain, let code = AuthErrorCode.Code(rawValue: error.code),
              [.credentialAlreadyInUse, .emailAlreadyInUse].contains(code) else {
            return nil
        }
        // Apple returns a refreshed credential after a collision; do not reuse its consumed token.
        return error.userInfo[AuthErrorUserInfoUpdatedCredentialKey] as? AuthCredential ?? original
    }

    func cancelExistingSignIn() {
        pendingCredential = nil
        hasPendingSignIn = false
    }

    func confirmExistingSignIn() async -> Bool {
        guard !isWorking, let credential = pendingCredential else { return false }
        isWorking = true
        errorMessage = nil
        cancelExistingSignIn()
        defer { isWorking = false }
        do {
            guard auth.currentUser?.uid == userID else { throw AccountOperationError.signedOut }
            // Firebase replaces the session only after successful authentication. No signOut here:
            // cancellation or a wrong password must leave the anonymous account accessible.
            _ = try await auth.signIn(with: credential)
            return true
        } catch {
            show(error)
            return false
        }
    }

    func sendPasswordReset(email: String) async -> Bool {
        guard !isWorking, !hasPendingSignIn else { return false }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await auth.sendPasswordReset(withEmail: email.trimmingCharacters(in: .whitespacesAndNewlines))
            return true
        } catch {
            show(error)
            return false
        }
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
            return "別のログイン方法で登録されているアカウントです。以前使ったログイン方法を選んでください。今の写真や手紙はそのまま残っています。"
        case .providerAlreadyLinked:
            return "この認証方法はすでに連携済みです。"
        case .invalidEmail:
            return "メールアドレスを確認してください。"
        case .weakPassword:
            return "パスワードが条件を満たしていません。より長く、複雑なパスワードを入力してください。"
        case .networkError:
            return "通信できませんでした。接続を確認して、もう一度お試しください。"
        case .wrongPassword, .userNotFound:
            return "メールアドレスまたはパスワードを確認してください。"
        case .invalidCredential:
            return "認証情報が正しくないか、有効期限が切れています。入力内容を確認して、もう一度お試しください。"
        default:
            return "認証できませんでした。もう一度お試しください。"
        }
    }
}
