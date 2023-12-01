// SpotifyAPI.swift
import Foundation
import Alamofire

class SpotifyAPI {
    static let shared = SpotifyAPI()

    private let baseURL = "https://api.spotify.com/v1"

    private init() {}

 
    func searchTracks(query: String, completion: @escaping ([Track]) -> Void) {
        SpotifyAuth.shared.requestAccessToken()

        guard let accessToken = SpotifyAuth.shared.accessToken else {
            print("Access token is nil.")
            return
        }

        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(accessToken)"
        ]

        let searchURL = "\(baseURL)/search"
        let parameters: [String: Any] = [
            "q": query,
            "type": "track"
        ]

        AF.request(searchURL, method: .get, parameters: parameters, headers: headers)
            .validate()
            .responseJSON { response in
                switch response.result {
                case .success(let data):
                    if let json = data as? [String: Any],
                       let tracksJSON = json["tracks"] as? [String: Any],
                       let items = tracksJSON["items"] as? [[String: Any]] {

                        var tracks: [Track] = []

                        for item in items {
                            if let id = item["id"] as? String,
                               let name = item["name"] as? String,
                               let artists = item["artists"] as? [[String: Any]],
                               let artist = artists.first?["name"] as? String {
                                let track = Track(id: id, name: name, artist: artist)
                                tracks.append(track)
                            }
                        }

                        completion(tracks)
                    } else {
                        print("Invalid response format")
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

  
    func requestAccessToken() {
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
                }
            case .failure(let error):
                print("Error: \(error)")
            }
        }
    }

    private var base64EncodedCredentials: String {
        let credentials = "\(clientID):\(clientSecret)"
        let data = credentials.data(using: .utf8)!
        return data.base64EncodedString()
    }
}
