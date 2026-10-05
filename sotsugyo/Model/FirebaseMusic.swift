//
//  FirebaseMusic.swift
//  sotsugyo
//
//  Created by saki on 2023/12/06.
//
import Foundation

struct FirebaseMusic: Identifiable {
    /// The photo document ID. `trackId` is the Spotify track ID stored as `id` in Firestore.
    var id: String
    var artistName: String
    var imageName: String
    var trackName: String
    var trackId: String
    var previewURL: String
}

extension FirebaseMusic {
    init?(photoID: String, data: [String: Any]) {
        guard let trackID = data["id"] as? String, !trackID.isEmpty else { return nil }
        self.init(
            id: photoID,
            artistName: data["artistName"] as? String ?? "",
            imageName: data["imageName"] as? String ?? "",
            trackName: data["trackName"] as? String ?? "",
            trackId: trackID,
            previewURL: data["previewUrl"] as? String ?? ""
        )
    }

    init(photoID: String, track: Track) {
        self.init(id: photoID, artistName: track.artist,
                  imageName: track.albumImages.first ?? "", trackName: track.name,
                  trackId: track.id, previewURL: track.previewURL ?? "")
    }

    var firestoreData: [String: Any] {
        ["artistName": artistName, "imageName": imageName,
         "trackName": trackName, "id": trackId, "previewUrl": previewURL]
    }

    var playablePreviewURL: URL? {
        guard !previewURL.isEmpty, let url = URL(string: previewURL),
              url.scheme == "https" || url.scheme == "http",
              let host = url.host, !host.isEmpty else { return nil }
        return url
    }
}
