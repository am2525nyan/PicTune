//
//  loginView.swift
//  sotsugyo
//
//  Created by saki on 2023/10/29.
//
import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseAuthUI
import FirebaseGoogleAuthUI
import FirebaseOAuthUI
import FirebaseEmailAuthUI
import FirebaseFirestore

struct LoginView: UIViewControllerRepresentable {
    @ObservedObject var viewModel: MainContentModel
    var onError: (String) -> Void = { _ in }

    func makeUIViewController(context: Context) -> UIViewController {
        let authUI = FUIAuth.defaultAuthUI()
        guard authUI != nil else {
            return UIViewController()
        }

        // サポートするログイン方法を構成
        let providers: [FUIAuthProvider] = [
            FUIGoogleAuth(authUI: authUI!),
            FUIOAuth.appleAuthProvider(),
            FUIEmailAuth()
        ]
        authUI!.providers = providers
        // This screen signs into an existing account. Linking is handled in Settings.
        authUI!.shouldAutoUpgradeAnonymousUsers = false



        // FirebaseUIを表示する
        let authViewController = authUI!.authViewController()
        authViewController.view.accessibilityIdentifier = "auth.existingLogin"


        // デリゲートを設定
        authUI!.delegate = context.coordinator
        return authViewController
    }

    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        // 処理なし
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel, onError: onError)
    }

    @MainActor class Coordinator: NSObject, FUIAuthDelegate {
        var viewModel: MainContentModel
        private let onError: (String) -> Void

        init(viewModel: MainContentModel, onError: @escaping (String) -> Void = { _ in }) {
            self.viewModel = viewModel
            self.onError = onError
        }

        @objc nonisolated func authUI(_ authUI: FUIAuth, didSignInWith authDataResult: AuthDataResult?, error: Error?) {
            let signedIn = authDataResult != nil
            Task { @MainActor in
                self.completeSignIn(signedIn: signedIn, error: error)
            }
        }

        func completeSignIn(signedIn: Bool, error: Error?) {
            if let error = error as NSError? {
                if !(error.domain == FUIAuthErrorDomain && error.code == FUIAuthErrorCode.userCancelledSignIn.rawValue) {
                    // FirebaseUI wraps provider failures without a useful description.
                    let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError
                    onError((underlying ?? error).localizedDescription)
                }
                viewModel.isShowSheet = false
            } else if signedIn {
                viewModel.isShowSheet = false
            }
        }


    }

}
/// Fill missing account fields without replacing an edited name or the library date.
enum UserAccountBootstrap {
    static func missingProfileFields(existing: [String: Any], profile: UserProfile, userID: String) -> [String: Any] {
        var fields = profile.firestoreData(userID: userID).filter { existing[$0.key] == nil }
        // Anonymous accounts have no email. Fill it on linking without overwriting edited names.
        if (existing["email"] as? String)?.isEmpty == true, let email = profile.email, !email.isEmpty {
            fields["email"] = email
        }
        return fields
    }

    static func save(userID: String, profile: UserProfile, database: Firestore? = nil) async throws {
        let db = database ?? Firestore.firestore()
        let user = db.collection("users").document(userID)
        let profileReference = user.collection("personal").document("info")
        let libraryReference = user.collection("folders").document("all")
        _ = try await db.runTransaction { transaction, errorPointer in
            do {
                let profileDocument = try transaction.getDocument(profileReference)
                let libraryDocument = try transaction.getDocument(libraryReference)
                let fields = missingProfileFields(existing: profileDocument.data() ?? [:], profile: profile, userID: userID)
                if !fields.isEmpty {
                    transaction.setData(fields, forDocument: profileReference, merge: true)
                }
                if !libraryDocument.exists {
                    transaction.setData(["title": "all", "date": FieldValue.serverTimestamp()], forDocument: libraryReference)
                }
                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
    }
}
