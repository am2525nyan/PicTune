//
//  FriendQRViewModel.swift
//  sotsugyo
//

import Combine
import FirebaseFirestore

@MainActor
final class FriendQRViewModel: ObservableObject {
    @Published var showAlert = false
    @Published private(set) var alertMessage = ""

    private let profileLoader: (String) async throws -> UserProfile?

    init(profileLoader: @escaping (String) async throws -> UserProfile? = { uid in
        let document = try await Firestore.firestore()
            .collection("users").document(uid)
            .collection("personal").document("info").getDocument()
        guard document.exists else { return nil }
        return UserProfile(documentData: document.data() ?? [:])
    }) {
        self.profileLoader = profileLoader
    }

    /// プロフィールを確認できた場合にのみ、撮影相手の UID を返します。
    func loadFriendProfile(uid: String) async -> String? {
        do {
            guard let profile = try await profileLoader(uid) else {
                showAlert(message: "User info not found")
                return nil
            }

            guard let name = profile.name else {
                showAlert(message: "User info is incomplete")
                return nil
            }

            showAlert(message: " \(name)さんと撮ります")
            return uid
        } catch {
            print("Error getting user info: \(error.localizedDescription)")
            showAlert(message: "Error getting user info")
            return nil
        }
    }

    private func showAlert(message: String) {
        alertMessage = message
        showAlert = true
    }
}
