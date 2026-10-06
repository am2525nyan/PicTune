import Foundation
import MusicKit

enum AppleMusicError: LocalizedError {
    case permissionDenied, restricted, configuration, unavailable, invalidResponse, rateLimited

    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "設定アプリでPicTuneの「メディアとApple Music」へのアクセスを許可してください。"
        case .restricted: return "この端末ではApple Musicへのアクセスが制限されています。"
        case .configuration: return "Apple Musicに接続できませんでした。時間をおいて、もう一度お試しください。"
        case .unavailable: return "この地域では曲を取得できないか、配信が終了しています。"
        case .invalidResponse: return "曲の情報を取得できませんでした。もう一度お試しください。"
        case .rateLimited: return "検索が混み合っています。少し待ってからお試しください。"
        }
    }
}

/// Catalog requests use a developer token, without requiring a paid user subscription.
/// MusicKit authorization and an App ID with MusicKit enabled are still required.
@MainActor
final class AppleMusicAPI {
    static let shared = AppleMusicAPI()
    typealias Transport = (URLRequest) async throws -> (Data, HTTPURLResponse)

    private let authorize: () async -> MusicAuthorization.Status
    private let developerToken: () async throws -> String
    private let countryCode: () async throws -> String
    private let transport: Transport

    init(authorize: @escaping () async -> MusicAuthorization.Status = { await MusicAuthorization.request() },
         developerToken: @escaping () async throws -> String = {
             try await DefaultMusicTokenProvider().developerToken(options: [])
         },
         countryCode: @escaping () async throws -> String = { try await MusicDataRequest.currentCountryCode },
         transport: @escaping Transport = { request in
             let (data, response) = try await URLSession.shared.data(for: request)
             guard let response = response as? HTTPURLResponse else { throw AppleMusicError.invalidResponse }
             return (data, response)
         }) {
        self.authorize = authorize
        self.developerToken = developerToken
        self.countryCode = countryCode
        self.transport = transport
    }

    func searchTracks(query: String) async throws -> [Track] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        let context = try await requestContext()
        let data = try await request(path: "search", context: context, query: [
            URLQueryItem(name: "term", value: query), URLQueryItem(name: "types", value: "songs"),
            URLQueryItem(name: "limit", value: "25")
        ])
        let response = try JSONDecoder().decode(SearchResponse.self, from: data)
        return (response.results.songs?.data ?? []).map { $0.track(storefront: context.storefront) }
    }

    func refreshTrack(_ track: Track) async throws -> Track {
        guard track.provider == .appleMusic, !track.id.isEmpty,
              track.id.allSatisfy({ $0.isASCII && $0.isNumber }) else { throw AppleMusicError.unavailable }
        let context = try await requestContext()
        // Resolve in the listener's storefront. Never play a stale sender's preview as a fallback.
        let data = try await request(path: "songs/\(track.id)", context: context)
        let response = try JSONDecoder().decode(SongsResponse.self, from: data)
        guard let song = response.data.first(where: { $0.id == track.id }) else { throw AppleMusicError.unavailable }
        return song.track(storefront: context.storefront)
    }

    private func requestContext() async throws -> (token: String, storefront: String) {
        switch await authorize() {
        case .authorized: break
        case .restricted: throw AppleMusicError.restricted
        default: throw AppleMusicError.permissionDenied
        }
        try Task.checkCancellation()
        let token = try await developerToken()
        let storefront = try await countryCode().lowercased()
        guard storefront.count == 2, storefront.allSatisfy({ $0.isASCII && $0.isLetter }) else {
            throw AppleMusicError.invalidResponse
        }
        return (token, storefront)
    }

    private func request(path: String, context: (token: String, storefront: String),
                         query: [URLQueryItem] = []) async throws -> Data {
        var components = URLComponents(string: "https://api.music.apple.com/v1/catalog/\(context.storefront)/\(path)")!
        if !query.isEmpty { components.queryItems = query }
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 20
        request.setValue("Bearer \(context.token)", forHTTPHeaderField: "Authorization")
        try Task.checkCancellation()
        let (data, response) = try await transport(request)
        try Task.checkCancellation()
        switch response.statusCode {
        case 200: return data
        case 401, 403: throw AppleMusicError.configuration
        case 404: throw AppleMusicError.unavailable
        case 429: throw AppleMusicError.rateLimited
        default: throw AppleMusicError.invalidResponse
        }
    }

    private struct SearchResponse: Decodable {
        let results: Results
        struct Results: Decodable { let songs: SongsResponse? }
    }
    private struct SongsResponse: Decodable { let data: [CatalogSong] }
    private struct CatalogSong: Decodable {
        let id: String
        let attributes: Attributes
        struct Attributes: Decodable {
            let name: String
            let artistName: String
            let albumName: String?
            let url: String?
            let isrc: String?
            let artwork: Artwork?
            let previews: [Preview]?
        }
        struct Artwork: Decodable { let url: String }
        struct Preview: Decodable { let url: String? }

        func track(storefront: String) -> Track {
            let artwork = attributes.artwork?.url
                .replacingOccurrences(of: "{w}", with: "300")
                .replacingOccurrences(of: "{h}", with: "300")
            return Track(id: id, name: attributes.name, artist: attributes.artistName,
                         albumImages: artwork.map { [$0] } ?? [],
                         previewURL: attributes.previews?.compactMap(\.url).first,
                         albumName: attributes.albumName, provider: .appleMusic,
                         musicURL: attributes.url, storefront: storefront, isrc: attributes.isrc)
        }
    }
}
