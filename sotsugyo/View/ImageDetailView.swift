//
//  ImageDetailView.swift
//  sotsugyo
//
//  Created by saki on 2023/12/04.
//

import SwiftUI

// ImageDetailView.swift
struct ImageDetailView: View {
    
    @Binding var image: UIImage?
    @ObservedObject var viewModel = MainContentModel()

    var body: some View {
        VStack {
            if let unwrappedImage = image {
                Image(uiImage: unwrappedImage)
                    .resizable()
                    .scaledToFit()
                    .navigationBarTitle("画像詳細", displayMode: .inline)
                
                // 画像に対応する日付を表示
                if let index = viewModel.images.firstIndex(where: { $0.isEqual(unwrappedImage) }), viewModel.dates.indices.contains(index) {
                    let correspondingDate = viewModel.dates[index]
                    Text("日付: \(correspondingDate)")
                        .padding()
                } else {
                    Text("日付情報がありません")
                        .padding()
                }
            }
        }
        .onAppear {
            // 画像に関連するテキスト情報と日付を取得
            Task {
                do {
                    try await viewModel.getDate()
                } catch {
                    print("テキスト情報の取得に失敗しました: \(error)")
                }
            }
        }
        .background(Color(red: 229 / 255, green: 217 / 255, blue: 255 / 255, opacity: 1.0))
    }
}
