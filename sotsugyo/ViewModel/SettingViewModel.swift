//
//  SettingViewModel.swift
//  sotsugyo
//
//  Created by saki on 2024/01/11.
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import GoogleSignIn
import UIKit

@MainActor
class SettingViewModel: ObservableObject {
    @Published internal var showingPasswordAlert = false
    @Published private(set) var profile = UserProfile()
    @Published private(set) var isDeleting = false
    @Published var operationError: String?
    @Published private(set) var isAnonymous: Bool
    @Published private(set) var linkedProviderIDs: Set<String>
    let authorizationDelegate = AuthorizationDelegate()
    private var pendingDeletionUserID: String?

    var mailAddress: String { profile.email ?? "" }
    var name: String { profile.name ?? "" }

    init(profile: UserProfile = UserProfile(), isAnonymous: Bool? = nil, linkedProviderIDs: Set<String>? = nil) {
        self.profile = profile
        self.isAnonymous = isAnonymous ?? Auth.auth().currentUser?.isAnonymous ?? false
        self.linkedProviderIDs = linkedProviderIDs ?? Set(Auth.auth().currentUser?.providerData.map(\.providerID) ?? [])
        authorizationDelegate.onCompletion = { [weak self] error in
            self?.isDeleting = false
            if let error { self?.operationError = error.localizedDescription }
        }
    }

    func loadProfile() async throws {
        guard let currentUser = Auth.auth().currentUser else { throw AccountOperationError.signedOut }
        refreshAccount()
        let document = try await Firestore.firestore()
            .collection("users").document(currentUser.uid)
            .collection("personal").document("info").getDocument()
        guard Auth.auth().currentUser?.uid == currentUser.uid else { throw AccountOperationError.signedOut }
        profile = UserProfile(
            documentData: document.data() ?? [:],
            fallbackEmail: currentUser.email
        )
    }

    func saveName(name: String) async throws {
        guard let currentUser = Auth.auth().currentUser else { throw AccountOperationError.signedOut }
        // The profile may not exist yet if initial registration failed offline.
        try await Firestore.firestore().collection("users").document(currentUser.uid)
            .collection("personal").document("info").setData(["name": name], merge: true)
        guard Auth.auth().currentUser?.uid == currentUser.uid else { throw AccountOperationError.signedOut }
        profile.name = name
    }

    func logout() {
        guard !isDeleting, Auth.auth().currentUser?.isAnonymous != true else { return }
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            profile = UserProfile()
        } catch {
            operationError = error.localizedDescription
        }
    }

    func deleteUser() {
        guard !isDeleting else { return }
        guard let user = Auth.auth().currentUser else {
            operationError = AccountOperationError.signedOut.localizedDescription
            return
        }
        operationError = nil
        pendingDeletionUserID = user.uid
        let providers = user.providerData.map(\.providerID)
        // A linked account must start only one reauthentication flow.
        if user.isAnonymous {
            isDeleting = true
            Task {
                defer { isDeleting = false }
                do {
                    guard Auth.auth().currentUser?.uid == user.uid else { throw AccountOperationError.signedOut }
                    try await user.delete()
                } catch {
                    operationError = error.localizedDescription
                }
            }
        } else if providers.contains("apple.com") {
            isDeleting = true
            authorizationDelegate.deleteCurrentUser(user)
        } else if providers.contains("password") {
            showingPasswordAlert = true
        } else if providers.contains("google.com") {
            isDeleting = true
            Task {
                defer { isDeleting = false }
                do {
                    guard let clientID = FirebaseApp.app()?.options.clientID,
                          let presenter = Self.presentationController else {
                        throw AccountOperationError.unavailable
                    }
                    GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
                    // Request a fresh sign-in even after an app restart. A cached token may
                    // be missing or may not satisfy Firebase's recent-login requirement.
                    let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
                    guard Auth.auth().currentUser?.uid == user.uid else { throw AccountOperationError.signedOut }
                    guard let idToken = result.user.idToken?.tokenString else { throw AccountOperationError.unavailable }
                    let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                                  accessToken: result.user.accessToken.tokenString)
                    try await AccountDeletion.perform(reauthenticate: {
                        _ = try await user.reauthenticate(with: credential)
                    }, delete: {
                        guard Auth.auth().currentUser?.uid == user.uid else { throw AccountOperationError.signedOut }
                        try await user.delete()
                    })
                    GIDSignIn.sharedInstance.signOut()
                } catch {
                    operationError = error.localizedDescription
                }
            }
        } else {
            operationError = AccountOperationError.unavailable.localizedDescription
        }
    }

    func reauthenticateWithPassword(password: String) {
        guard !isDeleting else { return }
        guard let user = Auth.auth().currentUser,
              user.uid == pendingDeletionUserID, let email = user.email else {
            operationError = AccountOperationError.signedOut.localizedDescription
            return
        }
        isDeleting = true
        Task {
            defer { isDeleting = false }
            do {
                let credential = EmailAuthProvider.credential(withEmail: email, password: password)
                try await AccountDeletion.perform(reauthenticate: {
                    _ = try await user.reauthenticate(with: credential)
                }, delete: {
                    guard Auth.auth().currentUser?.uid == user.uid else { throw AccountOperationError.signedOut }
                    try await user.delete()
                })
            } catch {
                operationError = error.localizedDescription
            }
        }
    }

    static var presentationWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .flatMap(\.windows).first(where: \.isKeyWindow)
    }

    static var presentationController: UIViewController? {
        var controller = presentationWindow?.rootViewController
        while let presented = controller?.presentedViewController { controller = presented }
        return controller
    }

    func refreshAccount() {
        let user = Auth.auth().currentUser
        isAnonymous = user?.isAnonymous ?? false
        linkedProviderIDs = Set(user?.providerData.map(\.providerID) ?? [])
    }

    func didLinkAccount() async throws {
        guard let user = Auth.auth().currentUser else { throw AccountOperationError.signedOut }
        refreshAccount()
        // Update the display immediately, even when the profile write needs a later retry.
        if profile.email?.isEmpty != false { profile.email = user.email }
        try await UserAccountBootstrap.save(userID: user.uid,
                                            profile: UserProfile(name: user.displayName, email: user.email))
        guard Auth.auth().currentUser?.uid == user.uid else { throw AccountOperationError.signedOut }
        try await loadProfile()
    }
}

enum AccountOperationError: LocalizedError {
    case signedOut
    case unavailable

    var errorDescription: String? {
        switch self {
        case .signedOut: return "ログインし直してください。"
        case .unavailable: return "再認証を開始できませんでした。もう一度お試しください。"
        }
    }
}

/// Never revoke tokens or delete an account after failed reauthentication.
@MainActor
enum AccountDeletion {
    static func perform(reauthenticate: () async throws -> Void,
                        revoke: () async throws -> Void = {},
                        delete: () async throws -> Void) async throws {
        try await reauthenticate()
        try await revoke()
        try await delete()
    }
}
