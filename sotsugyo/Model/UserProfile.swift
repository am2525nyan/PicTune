//
//  UserProfile.swift
//  sotsugyo
//

/// `users/{uid}/personal/info` に保存するプロフィール。
/// 名前の欠損と空文字は、QR 読み取り時に区別するため保持します。
struct UserProfile: Equatable {
    var name: String?
    var email: String?

    init(name: String? = nil, email: String? = nil) {
        self.name = name
        self.email = email
    }

    init(documentData: [String: Any], fallbackEmail: String? = nil) {
        name = documentData["name"] as? String
        email = documentData["email"] as? String ?? fallbackEmail
    }

    func firestoreData(userID: String) -> [String: Any] {
        ["uid": userID, "email": email ?? "", "name": name ?? ""]
    }
}
