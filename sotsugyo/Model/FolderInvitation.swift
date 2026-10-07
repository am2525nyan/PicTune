import Foundation
import CryptoKit

struct FolderInviteLink: Equatable, Identifiable {
    static let host = "sotugyou-7ea16.web.app"
    let token: String
    var id: String { token }
    var url: URL { URL(string: "https://\(Self.host)/invite/\(token)")! }

    init(token: String) { self.token = token }

    init?(url: URL) {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.user == nil, parts.password == nil, parts.port == nil,
              parts.query == nil, parts.fragment == nil else { return nil }
        let path = parts.path.split(separator: "/", omittingEmptySubsequences: false)
        if parts.scheme == "https", parts.host == Self.host,
           path.count == 3, path[0].isEmpty, path[1] == "invite" {
            token = String(path[2])
        } else if parts.scheme == "pictune", parts.host == "invite",
                  path.count == 2, path[0].isEmpty {
            token = String(path[1])
        } else { return nil }
        guard token.count == 64, token.allSatisfy({ "0123456789abcdef".contains($0) }) else { return nil }
    }

    static func make() -> Self {
        Self(token: SymmetricKey(size: .bits256).withUnsafeBytes { bytes in
            bytes.map { String(format: "%02x", $0) }.joined()
        })
    }
}

struct LiveSharedFolder: Identifiable, Equatable {
    let ownerID: String
    let folderID: String
    let title: String
    var id: String {
        SHA256.hash(data: Data("\(ownerID)/\(folderID)".utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

struct FolderInvitation {
    let link: FolderInviteLink
    let folder: LiveSharedFolder
    let senderName: String
    let expiresAt: Date
    let isRevoked: Bool
    func isAvailable(at date: Date = Date()) -> Bool { !isRevoked && expiresAt > date }
}

enum FolderInviteError: LocalizedError {
    case signInRequired, unavailable, ownFolder, missingFolder, invalidLink
    var errorDescription: String? {
        switch self {
        case .signInRequired: return "ログインしてから、招待リンクを開いてください。"
        case .unavailable: return "この招待リンクは期限が切れているか、無効になっています。送り主に新しいリンクをお願いしてください。"
        case .ownFolder: return "これはご自身のフォルダです。フォルダ画面からご覧いただけます。"
        case .missingFolder: return "共有が終了したか、フォルダが削除されました。"
        case .invalidLink: return "招待リンクの形式が正しくありません。届いたリンク全体を開いてください。"
        }
    }
}
