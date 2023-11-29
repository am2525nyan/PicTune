//
//  SearchMusicView.swift
//  sotsugyo
//
//  Created by saki on 2023/11/27.
//
import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct SearchMusicView: View {
    @StateObject private var viewModel = SearchMusicViewModel()
    @State var isAlart: Bool = false
    @Binding var isPresentingSearchMusic: Bool
    var body: some View {
        NavigationView {
            VStack {
                SearchBar(
                    text: $viewModel.searchText,
                    isFocused: $viewModel.isSearchBarFocused,
                    onSearchTextChanged: viewModel.searchBarTextChanged
                )
                
                List(viewModel.musicList, id: \.id) { music in
                    if let index = viewModel.musicList.firstIndex(where: { $0.id == music.id }),
                       index < viewModel.artworks.count {
                        HStack {
                            Image(uiImage: viewModel.artworks[index])
                                .resizable()
                                .scaledToFit()
                                .frame(width: 50, height: 50)
                            
                            Text(music.trackName)
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 5))
                        // タップした時にtapActionを実行
                        .onTapGesture {
                            Task{
                                do{
                                    try await tapAction(selection: music.trackName, Url:  music.previewUrl)
                                    
                                }
                            }
                        }
                    }
                }
                .alert(isPresented: $isAlart) {
                    Alert(title: Text("保存しました！"))
                    
                    
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("音楽を設定")
        }
    }
    func tapAction(selection: String,Url: String) async throws{
        let db = Firestore.firestore()
        
        if let currentUser = Auth.auth().currentUser {
            let uid = currentUser.uid
            try await db.collection("users").document(uid).collection("personal").document("info").updateData([
                "music": [
                    "trackName": selection,
                    "previewUrl": Url
                ]
            ])
        }
        
        isAlart = true
       isPresentingSearchMusic = true
    }
    
    
    struct SearchMusicView_Previews: PreviewProvider {
        static var previews: some View {
            SearchMusicView(isPresentingSearchMusic: .constant(false))
        }
    }
    
    struct SearchBar: View {
        @Binding var text: String
        @Binding var isFocused: Bool
        var onSearchTextChanged: () -> Void
        
        var body: some View {
            HStack {
                TextField("Search...", text: $text, onEditingChanged: { isEditing in
                    if isEditing {
                        isFocused = true
                    } else {
                        isFocused = false
                    }
                })
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
                .onChange(of: text) {
                    onSearchTextChanged()
                }
                
                if !text.isEmpty {
                    Button(action: {
                        text = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .padding(.trailing, 8)
                }
            }
        }
        
    }
}
