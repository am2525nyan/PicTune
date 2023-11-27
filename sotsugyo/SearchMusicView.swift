//
//  SearchMusicView.swift
//  sotsugyo
//
//  Created by saki on 2023/11/27.
//
import SwiftUI
struct SearchMusicView: View {
    @State var musicList: [Music] = []
    @State private var text = ""
    @State  var artworks :[UIImage] = []
    @State private var searchText: String = ""
    @State private var isSearchBarFocused: Bool = false
    @Binding var isPresentingSearchMusic: Bool

    var body: some View {
        NavigationView {
            VStack {
                // 検索バー
                SearchBar(text: $searchText, isFocused: $isSearchBarFocused, onSearchBarClicked: searchBarClicked)

                // 検索結果を表示するList
                // 検索結果を表示するList
                List(musicList, id: \.id) { music in
                    if let index = musicList.firstIndex(where: { $0.id == music.id }),
                       index < artworks.count { // インデックスが有効な範囲内かどうかを確認
                        Image(uiImage: artworks[index])
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50, height: 50)

                        Text(music.trackName)
                    }
                }




               

                .listStyle(PlainListStyle())
            }
            .navigationTitle("Search Music")
        }
    }
    func getImage(url: URL)async -> UIImage? {
        do{
            let (data,_) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else{ return nil }
            return image
        }catch{
            return nil
        }
    }

    func searchBarClicked() {
           let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines) // 空白を取り除く
           guard !text.isEmpty else {
               // 検索テキストが空の場合は何もしない
               return
           }

           Task {
               let response: MusicResponse? = await requestMusic(keyword: text)
               guard let musicResult = response else {
                   print("Failed to fetch music data")
                   return
               }
               artworks = []
               for music in musicList{
                   let image = await getImage(url: music.artworkUrl60)
                   artworks.append(image!)
               }
               musicList = musicResult.result
           }
       }


    func requestMusic(keyword: String) async -> MusicResponse? {
        let urlString = "https://itunes.apple.com/search?term=\(keyword)&entity=song&country=JP&lang=ja_jp&limit=20"
        guard let encodedUrlString = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        guard let url = URL(string: encodedUrlString) else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse else { return nil }
            if httpResponse.statusCode == 200 {
                let decodedData = try JSONDecoder().decode(MusicResponse.self, from: data)
                return decodedData
            } else {
                return nil
            }
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
    var onSearchBarClicked: () -> Void

    var body: some View {
        HStack {
            TextField("Search...", text: $text, onEditingChanged: { isEditing in
                if isEditing {
                    // 検索バーがフォーカスされた時
                    isFocused = true
                    onSearchBarClicked()
                } else {
                    // 検索バーがフォーカスを失った時
                    isFocused = false
                }
            })
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .padding(.horizontal)

            if !text.isEmpty {
                Button(action: {
                    // クリアボタンを押した時
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

