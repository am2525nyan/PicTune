//
//  SearchMusicView.swift
//  sotsugyo
//
//  Created by saki on 2023/11/27.
//


import SwiftUI
import URLImage

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @State private var searchText: String = ""
    @State private var tracks: [Track] = []
    @State var isPresentingSearch =  true
    @State private var documentId: String
       
       init(documentId: String) {
           self._documentId = State(initialValue: documentId)
       }

    var body: some View {
        VStack {
            TextField("曲を検索", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
                .onChange(of: searchText) {
                    SpotifyAPI.shared.searchTracks(query: searchText) { searchResults in
                        tracks = searchResults
                    }
                }
            
            List(tracks) { track in
                HStack {
                    
                    if let firstImageURL = track.albumImages.first, let imageURL = URL(string: firstImageURL) {
                        URLImage(imageURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 50, height: 50)
                        }
                    } else {
                        
                        Text("Invalid URL")
                    }
                    
                    
                    VStack(alignment: .leading) {
                        Text(track.name)
                            .font(.headline)
                        Text(track.artist)
                            .font(.subheadline)
                    }
                }
                .onTapGesture {
                    Task{
                        do{
                            try await viewModel.tapAction(trackName: track.name, Url: track.previewURL ?? "google.com")
                            
                        }
                    }
                    
                }
                .onAppear {
                    DispatchQueue.main.async {
                        viewModel.documentId = documentId
                    }
                        }
                
                
                
                .padding(.vertical, 8)
            }
            .contentShape(RoundedRectangle(cornerRadius: 5))
            
            
           
            
            
        }
        .padding()
        .onAppear{
            SpotifyAuth.shared.requestAccessToken()
            print("SearchView appeared")
           print(self.documentId,"searchmusicView2")
        }
        .navigationTitle("音楽検索")
    }
}

