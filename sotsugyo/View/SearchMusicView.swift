//
//  SearchMusicView.swift
//  sotsugyo
//
//  Created by saki on 2023/11/27.
//

// SearchView.swift
// SearchView.swift
import SwiftUI

struct SearchView: View {
    @State private var searchText: String = ""
    @State private var tracks: [Track] = []

    var body: some View {
        VStack {
            TextField("曲を検索", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button("検索") {
                SpotifyAPI.shared.searchTracks(query: searchText) { searchResults in
                    tracks = searchResults
                }
            }
            .padding()

            List(tracks) { track in
                VStack(alignment: .leading) {
                    Text(track.name)
                        .font(.headline)
                    Text(track.artist)
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .navigationTitle("Spotify検索")
    }
}

struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        SearchView()
    }
}

