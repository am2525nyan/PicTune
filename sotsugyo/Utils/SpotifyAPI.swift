// SpotifyAPI.swift
import Foundation
import Alamofire

class SpotifyAPI {
    static let shared = SpotifyAPI()
    
    private let baseURL = "https://api.spotify.com/v1"
    
    private init() {}
    
    func searchTracks(query: String, completion: @escaping (Result<[Track], Error>) -> Void) {
        SpotifyAuth.shared.fetchAccessToken { success in
            guard success, let accessToken = SpotifyAuth.shared.accessToken else {
                completion(.failure(NSError(domain: "MusicSearch", code: 1)))
                return
            }
            let headers: HTTPHeaders = ["Authorization": "Bearer \(accessToken)"]
            let parameters = ["q": query, "type": "track"]
            AF.request("\(self.baseURL)/search", method: .get, parameters: parameters, headers: headers)
                .validate()
                .responseJSON { response in
                    switch response.result {
                    case .success(let data):
                        guard let json = data as? [String: Any],
                              let tracksJSON = json["tracks"] as? [String: Any],
                              let items = tracksJSON["items"] as? [[String: Any]] else {
                            completion(.failure(NSError(domain: "MusicSearch", code: 2)))
                            return
                        }
                        let tracks = items.compactMap { item -> Track? in
                            guard let id = item["id"] as? String,
                                  let name = item["name"] as? String,
                                  let artists = item["artists"] as? [[String: Any]],
                                  let artist = artists.first?["name"] as? String else { return nil }
                            let album = item["album"] as? [String: Any]
                            let images = album?["images"] as? [[String: Any]] ?? []
                            return Track(id: id, name: name, artist: artist,
                                         albumImages: images.compactMap { $0["url"] as? String },
                                         previewURL: item["preview_url"] as? String,
                                         albumName: album?["name"] as? String)
                        }
                        completion(.success(tracks))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
        }
    }

    func getAlbumInfo(albumID: String, completion: @escaping ([String]) -> Void) {
        guard let accessToken = SpotifyAuth.shared.accessToken else {
            print("Access token is nil.")
            return
        }
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(accessToken)"
        ]
        
        let albumURL = "\(self.baseURL)/albums/\(albumID)"
        
        AF.request(albumURL, method: .get, headers: headers)
            .validate()
            .responseJSON { response in
                switch response.result {
                case .success(let data):
                    if let json = data as? [String: Any],
                       let images = json["images"] as? [[String: Any]] {
                        let albumImages = images.compactMap { $0["url"] as? String }
                        completion(albumImages)
                    } else {
                        print("Invalid album response format")
                    }
                case .failure(let error):
                    print("Error: \(error)")
                }
            }
    }
    
}

// SpotifyAuth.swift
import Foundation
import Alamofire

class SpotifyAuth: ObservableObject {
    static let shared = SpotifyAuth()
    
    private let clientID = "c1f459a776784f3783bea9e1803fd28b"
    private let clientSecret = "06b150a321fc443c8f839dd324a917a6"
    private let redirectURI = "http://localhost:8888/callback"
    
    @Published var accessToken: String?
    
    private init() {}
    
    func requestAccessToken(completion: @escaping (Bool) -> Void = { _ in }) {
        let base64EncodedCredentials = self.base64EncodedCredentials
        
        AF.request("https://accounts.spotify.com/api/token", method: .post, parameters: [
            "grant_type": "client_credentials"
        ], headers: ["Authorization": "Basic \(base64EncodedCredentials)"])
        .validate()
        .responseJSON { response in
            switch response.result {
            case .success(let data):
                if let json = data as? [String: Any],
                   let accessToken = json["access_token"] as? String {
                    self.accessToken = accessToken
                    completion(true)
                } else {
                    completion(false)
                }
            case .failure(let error):
                print("Error: \(error)")
                completion(false)
            }
        }
    }
    
    func fetchAccessToken(completion: @escaping (Bool) -> Void) {
        if self.accessToken != nil {
            completion(true)
            return
        }
        
        requestAccessToken(completion: completion)
    }
    
    private var base64EncodedCredentials: String {
        let credentials = "\(clientID):\(clientSecret)"
        let data = credentials.data(using: .utf8)!
        return data.base64EncodedString()
    }
    
    
    func playTrack(trackID: String) {
        SpotifyAuth.shared.fetchAccessToken { success in
            guard success, let accessToken = SpotifyAuth.shared.accessToken else {
                print("Access token is nil or not available.")
                return
            }
            
            let playEndpoint = "https://api.spotify.com/v1/me/player/play"
            
            let trackUri = "spotify:track:\(trackID)" // トラックのIDをURIに変換
            let parameters: [String: Any] = ["uris": [trackUri]]
            
            AF.request(playEndpoint, method: .put, parameters: parameters, encoding: JSONEncoding.default, headers: ["Authorization": "Bearer \(accessToken)", "Content-Type": "application/json"])
                .responseJSON { response in
                    switch response.result {
                    case .success:
                        print("Track played successfully")
                    case .failure(let error):
                        print("Error playing track: \(error.localizedDescription)")
                    }
                }
        }
    }
}
