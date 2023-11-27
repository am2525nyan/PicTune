//
//  SearchMusicView.swift
//  sotsugyo
//
//  Created by saki on 2023/11/27.
//
import SwiftUI

struct SearchMusicView: View {
    @State private var musicList: [Music] = []
    @State private var artworks: [UIImage] = []
    @State private var searchText: String = ""
    @State private var isSearchBarFocused: Bool = false
    @Binding var isPresentingSearchMusic: Bool

    var body: some View {
        NavigationView {
            VStack {
                
                SearchBar(text: $searchText, isFocused: $isSearchBarFocused, onSearchTextChanged: searchBarTextChanged)

               
                List(musicList, id: \.id) { music in
                    if let index = musicList.firstIndex(where: { $0.id == music.id }),
                       index < artworks.count {
                        HStack {
                            Image(uiImage: artworks[index])
                                .resizable()
                                .scaledToFit()
                                .frame(width: 50, height: 50)

                            Text(music.trackName)
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Search Music")
        }
    }

    func getImage(url: URL) async -> UIImage? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else { return nil }
            return image
        } catch {
            return nil
        }
    }

    func searchBarTextChanged() {
        let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
           
            return
        }

        Task {
            let response: MusicResponse? = await requestMusic(keyword: text)
            guard let musicResult = response else {
                print("Failed to fetch music data")
                return
            }
          
            artworks = []

          
            for music in musicResult.result {
                if let image = await getImage(url: music.artworkUrl60) {
                    artworks.append(image)
                }
            }

            musicList = musicResult.result
        }
    }

    func requestMusic(keyword: String) async -> MusicResponse? {
        let urlString = "https://itunes.apple.com/search?term=\(keyword)&entity=song&country=JP&lang=ja_jp&limit=20"
        guard let encodedUrlString = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }

        guard let url = URL(string: encodedUrlString) else {
            return nil
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }

            let decodedData = try JSONDecoder().decode(MusicResponse.self, from: data)
            return decodedData
        } catch {
            print(error)
            return nil
        }
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
