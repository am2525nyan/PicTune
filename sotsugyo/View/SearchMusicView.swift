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
    @State var artistName: String = ""
    @State var imageName: String = ""
    @State var Url: String = ""
    @State var previewUrl: String = ""
    @State  var documentId: String
    @Binding var friendUid: String
    
    
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
                        self.artistName = track.artist
                        self.imageName = track.albumImages.first ?? ""
                        self.previewUrl  = track.previewURL!
                        showAlert = true
                        
                        
                    }
                    
                    
                    .onAppear {
                        DispatchQueue.main.async {
                            viewModel.documentId = documentId
                            viewModel.isPresentingSearch = isPresentingSearch
                        }
                    }
                    .alert("保存", isPresented: $showAlert) {
                        Button("OK") {
                            showAlert = false
                            Task{
                                do{
                                    
                                    try await viewModel.tapAction(trackName: trackName,Url: Url,artistName: artistName, imageName: imageName, previewUrl: previewUrl, friendUid: friendUid)
                                    UIApplication.shared.windows.first{ $0.isKeyWindow }?.rootViewController?.dismiss(animated: true, completion: nil)
                                    
                                }
                            }
                        }
                    } message: {
                        Text("音楽を保存します")
                    }
                    
                    
                    .padding(.vertical, 8)
                }
                .contentShape(RoundedRectangle(cornerRadius: 5))
                
                
                
                
                
            }
            .padding()
            .onAppear{
                SpotifyAuth.shared.requestAccessToken()
            }
            .navigationTitle("音楽検索")
        }
    }
    
}
