
import Foundation

enum MusicProvider: String {
    case appleMusic
    case spotify
    case unknown

    var name: String {
        switch self {
        case .appleMusic: return "Apple Music"
        case .spotify: return "Spotify"
        case .unknown: return "音楽サービス"
        }
    }
}

struct Track: Identifiable {
    var id: String
    var name: String
    var artist: String
    var albumImages: [String]
    var previewURL: String?
    var albumName: String? = nil
    var provider: MusicProvider = .appleMusic
    var musicURL: String? = nil
    var storefront: String? = nil
    var isrc: String? = nil

    var selectionID: String { "\(provider.rawValue):\(id)" }

    var serviceURL: URL? {
        if let musicURL, let url = URL(string: musicURL), url.scheme == "https",
           (provider == .appleMusic && url.host == "music.apple.com") ||
           (provider == .spotify && url.host == "open.spotify.com") {
            return url
        }
        if provider == .spotify, !id.isEmpty,
           id.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) }) {
            return URL(string: "https://open.spotify.com/track/\(id)")
        }
        return nil
    }

    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "id": id, "trackName": name, "artistName": artist,
            "imageName": albumImages.first ?? "", "previewUrl": previewURL ?? "",
            "musicProvider": provider.rawValue
        ]
        data["musicURL"] = serviceURL?.absoluteString
        data["storefront"] = storefront
        data["isrc"] = isrc
        data["albumName"] = albumName
        return data
    }
}
