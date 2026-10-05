//
//  FirebaseMusic.swift
//  sotsugyo
//
//  Created by saki on 2023/12/06.
//


struct FirebaseMusic: Identifiable {
    var id: String
    var  artistName: String
    var  imageName: String
    var trackName:  String
    var trackId: String
    var previewURL: String
    var provider: MusicProvider = .spotify
    var musicURL: String? = nil
    var storefront: String? = nil
    var isrc: String? = nil

    var track: Track {
        Track(id: trackId, name: trackName, artist: artistName,
              albumImages: imageName.isEmpty ? [] : [imageName], previewURL: previewURL,
              provider: provider, musicURL: musicURL, storefront: storefront, isrc: isrc)
    }

    static func from(documentID: String, data: [String: Any]) -> FirebaseMusic? {
        guard let trackID = data["id"] as? String, !trackID.isEmpty else { return nil }
        let provider: MusicProvider
        if let rawProvider = data["musicProvider"] as? String {
            provider = MusicProvider(rawValue: rawProvider) ?? .unknown
        } else {
            provider = .spotify
        }
        return FirebaseMusic(id: documentID, artistName: data["artistName"] as? String ?? "",
                             imageName: data["imageName"] as? String ?? "",
                             trackName: data["trackName"] as? String ?? "", trackId: trackID,
                             previewURL: data["previewUrl"] as? String ?? "",
                             provider: provider, musicURL: data["musicURL"] as? String,
                             storefront: data["storefront"] as? String, isrc: data["isrc"] as? String)
    }
}
