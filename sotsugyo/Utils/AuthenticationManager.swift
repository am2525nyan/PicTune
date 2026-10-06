//
//  AuthenticationManager.swift
//  sotsugyo
//
//  Created by saki on 2023/10/29.
//

import Foundation
import Observation
import FirebaseAuth

@Observable class AuthenticationManager {
    private(set) var userID: String?
    var isSignIn: Bool { userID != nil }
    private var handle: AuthStateDidChangeListenerHandle?

    init() {
        userID = Auth.auth().currentUser?.uid
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.userID = user?.uid
            // Initialization belongs to the session, not the transient login sheet.
            // The sheet can be dismissed before its own auth listener runs.
            guard let user else { return }
            let uid = user.uid
            let profile = UserProfile(name: user.displayName, email: user.email)
            Task {
                do {
                    try await UserAccountBootstrap.save(userID: uid, profile: profile)
                } catch {
                    print("プロフィールの初期化に失敗しました: \(error.localizedDescription)")
                }
            }
        }
    }

    deinit {
        if let handle { Auth.auth().removeStateDidChangeListener(handle) }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            print("ログアウトに失敗しました: \(error.localizedDescription)")
        }
    }
}
