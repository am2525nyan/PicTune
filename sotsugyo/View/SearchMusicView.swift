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
    @Binding var isPresentingSearchMusic: Bool
    @State var isSearchBarFocused: Bool = false
    @State var selectedMusic: Music?
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationView {
            VStack {
                SearchBar(text: $viewModel.searchText, isFocused: $isSearchBarFocused, onSearchTextChanged: viewModel.searchBarTextChanged)
                
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
                                    try await viewModel.tapAction(trackName: music.trackName, Url:  music.previewUrl)
                                    
                                }
                            }
                        }
                    }
                }
                .alert("タイトル", isPresented: $viewModel.isAlart) {
                    Button("キャンセル") {
                    }
                    Button("OK") {
                        isPresentingSearchMusic = false
                       
                        
                    }
                } message: {
                    Text("ここに詳細メッセージを書きます。")
                }


                .listStyle(PlainListStyle())
            }
            .navigationTitle("音楽を設定")
                      
        }
        
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
