//
//  Music.swift
//  sotsugyo
//
//  Created by saki on 2023/11/27.
//

import Foundation
struct MusicResponse: Codable {
    var result: [Music]

    enum CodingKeys: String, CodingKey {
        case result = "results"
    }
}

struct Music: Codable, Identifiable {
    var id: Int
    var trackName: String
    var artworkUrl60: URL

    enum CodingKeys: String, CodingKey {
        case id = "trackId"
        case trackName
        case artworkUrl60
    }
}


