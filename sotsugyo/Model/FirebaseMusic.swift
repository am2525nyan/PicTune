//
//  FirebaseMusic.swift
//  sotsugyo
//
//  Created by saki on 2023/12/06.
//
import Foundation

struct FirebaseMusic: Identifiable {
    /// The photo document ID. `trackId` is the music service track ID stored as `id` in Firestore.
    var id: String
    var artistName: String
    var imageName: String
    var trackName: String
    var trackId: String
    var previewURL: String
    var provider: MusicProvider = .spotify
    var musicURL: String? = nil
    var storefront: String? = nil
    var isrc: String? = nil
    var albumName: String? = nil

    var track: Track {
        Track(id: trackId, name: trackName, artist: artistName,
              albumImages: imageName.isEmpty ? [] : [imageName], previewURL: previewURL,
              albumName: albumName, provider: provider, musicURL: musicURL, storefront: storefront, isrc: isrc)
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
                             storefront: data["storefront"] as? String, isrc: data["isrc"] as? String,
                             albumName: data["albumName"] as? String)
    }
}

extension FirebaseMusic {
    init?(photoID: String, data: [String: Any]) {
        guard let music = Self.from(documentID: photoID, data: data) else { return nil }
        self = music
    }

    init(photoID: String, track: Track) {
        self.init(id: photoID, artistName: track.artist,
                  imageName: track.albumImages.first ?? "", trackName: track.name,
                  trackId: track.id, previewURL: track.previewURL ?? "",
                  provider: track.provider, musicURL: track.musicURL, storefront: track.storefront,
                  isrc: track.isrc, albumName: track.albumName)
    }

    var firestoreData: [String: Any] {
        track.firestoreData
    }

    var playablePreviewURL: URL? {
        guard !previewURL.isEmpty, let url = URL(string: previewURL),
              url.scheme == "https" || url.scheme == "http",
              let host = url.host, !host.isEmpty else { return nil }
        return url
    }
}
