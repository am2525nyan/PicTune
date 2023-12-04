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
    @State var isPresentingSearch: Bool = true
    @State private var showAlert = false
    @State var trackName: String = ""
    @State var Url: String = ""
    @State private var documentId: String
    @Environment(\.dismiss) var dismiss
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
            
            HStack {
                List(tracks) { track in
                    HStack {
                        if let firstImageURL = track.albumImages.first, let imageURL = URL(string: firstImageURL) {
                            AsyncImage(url: imageURL) { phase in
                                switch phase {
                                case .empty:
                                    // Placeholder image or view
                                    Image(systemName: "photo")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 50, height: 50)
                                case .success(let image):
                                    // Successfully loaded image
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 50, height: 50)
                                case .failure:
                                    // Failed to load image
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(.red)
                                        .frame(width: 50, height: 50)
                                @unknown default:
                                    // Placeholder image or view for unknown state
                                    Image(systemName: "photo")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 50, height: 50)
                                }
                            }
                            
                            
                        }
                        VStack(alignment: .leading) {
                            Text(track.name)
                                .font(.headline)
                            Text(track.artist)
                                .font(.subheadline)
                            
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        self.trackName = track.name
                        self.Url = track.id
                        showAlert = true
                        
                        
                    }
                    
                    
                    .onAppear {
                        DispatchQueue.main.async {
                            viewModel.documentId = documentId
                            viewModel.isPresentingSearch = isPresentingSearch
                        }
                    }
                    .alert("タイトル", isPresented: $showAlert) {
                        Button("了解") {
                            showAlert = false
                            Task{
                                do{
                                    
                                    try await viewModel.tapAction(trackName: trackName, Url: Url )
                                    dismiss()
                                    
                                }
                            }
                        }
                    } message: {
                        Text("詳細メッセージ")
                    }
                    
                    
                    .padding(.vertical, 8)
                }
                .contentShape(RoundedRectangle(cornerRadius: 5))
                
                
                
                
                
            }
            .padding()
            .onAppear{
                SpotifyAuth.shared.requestAccessToken()
                print("SearchView appeared")
            }
            .navigationTitle("音楽検索")
        }
    }
    
}
