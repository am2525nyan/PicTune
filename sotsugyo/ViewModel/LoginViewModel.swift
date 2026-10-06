//
//  loginView.swift
//  sotsugyo
//
//  Created by saki on 2023/10/29.
//
import SwiftUI
import FirebaseAuthUI
import FirebaseGoogleAuthUI
import FirebaseOAuthUI
import FirebaseEmailAuthUI
import FirebaseFirestore

struct LoginView: UIViewControllerRepresentable {
    @ObservedObject var viewModel: MainContentModel

    func makeUIViewController(context: Context) -> UIViewController {
        guard let authUI = FUIAuth.defaultAuthUI() else {
            return UIViewController()
        }
        authUI.providers = [
            FUIGoogleAuth(authUI: authUI),
            FUIOAuth.appleAuthProvider(),
            FUIEmailAuth()
        ]
        return authUI.authViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) { }
}

/// Fill missing account fields without replacing an edited name or the library date.
enum UserAccountBootstrap {
    static func missingProfileFields(existing: [String: Any], profile: UserProfile, userID: String) -> [String: Any] {
        profile.firestoreData(userID: userID).filter { existing[$0.key] == nil }
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
