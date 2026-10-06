//
//  FriendQRViewModel.swift
//  sotsugyo
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class FriendQRViewModel: ObservableObject {
    @Published var showAlert = false
    @Published private(set) var alertMessage = ""
    @Published private(set) var confirmedUserID: String?

    private let profileLoader: (String) async throws -> UserProfile?
    private var requestID = UUID()

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
        let request = UUID()
        requestID = request
        confirmedUserID = nil
        guard !uid.isEmpty, uid.count <= 128, !uid.contains("/"),
              uid.rangeOfCharacter(from: .whitespacesAndNewlines.union(.controlCharacters)) == nil else {
            showAlert(message: "PicTuneのユーザーQRコードを読み取ってください。")
            return nil
        }
        do {
            let loaded = try await profileLoader(uid)
            guard requestID == request, !Task.isCancelled else { return nil }
            guard let profile = loaded else {
                showAlert(message: "User info not found")
                return nil
            }

            guard let name = profile.name else {
                showAlert(message: "User info is incomplete")
                return nil
            }

            confirmedUserID = uid
            showAlert(message: " \(name)さんと撮ります")
            return uid
        } catch {
            guard requestID == request, !Task.isCancelled else { return nil }
            print("Error getting user info: \(error.localizedDescription)")
            showAlert(message: "Error getting user info")
            return nil
        }
    }

    func reportScanFailure(_ error: Error) {
        requestID = UUID()
        confirmedUserID = nil
        showAlert(message: "QRコードを読み取れませんでした。\n\(error.localizedDescription)")
    }

    private func showAlert(message: String) {
        alertMessage = message
        showAlert = true
    }
}
