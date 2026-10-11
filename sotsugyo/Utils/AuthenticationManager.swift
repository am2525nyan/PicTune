//
//  AuthenticationManager.swift
//  sotsugyo
//
//  Created by saki on 2023/10/29.
//

import Foundation
import Observation
import FirebaseAuth

@MainActor @Observable class AuthenticationManager {
    private(set) var userID: String?
    var isSignIn: Bool { userID != nil }
    private(set) var isStartingSession = true
    private(set) var startupError: String?
    private var hasRestoredSession = false
    private var isCreatingAnonymousUser = false
    private let auth: Auth
    private let saveProfile: (String, UserProfile) async throws -> Void
    private var listener: AuthSessionListener?

    init(auth: Auth = Auth.auth(),
         saveProfile: @escaping (String, UserProfile) async throws -> Void = {
             try await UserAccountBootstrap.save(userID: $0, profile: $1)
         }) {
        self.auth = auth
        self.saveProfile = saveProfile
        userID = auth.currentUser?.uid
        listener = AuthSessionListener(auth: auth) { [weak self] _, user in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.userID = user?.uid
                let isInitialSession = !self.hasRestoredSession
                self.hasRestoredSession = true
                if let user {
                    self.isStartingSession = false
                    self.startupError = nil
                    do {
                        try await self.saveProfile(user.uid, UserProfile(name: user.displayName, email: user.email))
                    } catch {
                        print("プロフィールの初期化に失敗しました: \(error.localizedDescription)")
                    }
                } else if isInitialSession {
                    // Wait for Firebase's first restoration callback before creating an account.
                    await self.startAnonymously()
                } else {
                    // Explicit logout/deletion must leave the login screen available.
                    self.isStartingSession = false
                }
            }
        }
    }

    func startAnonymously() async {
        guard auth.currentUser == nil, !isCreatingAnonymousUser else { return }
        isCreatingAnonymousUser = true
        isStartingSession = true
        startupError = nil
        defer {
            isCreatingAnonymousUser = false
            isStartingSession = false
        }
        do {
            let result = try await auth.signInAnonymously()
            userID = result.user.uid
        } catch {
            startupError = "利用を開始できませんでした。通信環境を確認して、もう一度お試しください。"
        }
    }
}

private final class AuthSessionListener {
    private let auth: Auth
    private let handle: AuthStateDidChangeListenerHandle

    init(auth: Auth, listener: @escaping (Auth, User?) -> Void) {
        self.auth = auth
        handle = auth.addStateDidChangeListener(listener)
    }

    deinit { auth.removeStateDidChangeListener(handle) }
}
