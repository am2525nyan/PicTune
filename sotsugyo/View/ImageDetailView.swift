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
    @Binding var documentId: String
    @Binding var tapdocumentId: String
    @Binding var index: Int
    @State private var tracks: [Track] = []
    @ObservedObject var viewModel: MainContentModel
    @Binding var friendUid: String
    var selectedIndex: Int
    
    var body: some View {
        ZStack{
            Color(red: 229 / 255, green: 217 / 255, blue: 255 / 255, opacity: 1.0)
                .edgesIgnoringSafeArea(.all)
            VStack {
                VStack {
                    if let unwrappedImage = image {
                        Image(uiImage: unwrappedImage)
                            .resizable()
                            .scaledToFit()
                            .navigationBarTitle("画像詳細", displayMode: .inline)
                    }
                }
                VStack {
                    
                    if let music = viewModel.Music.first {
                        
                        HStack {
                            AsyncImage(url: URL(string: music.imageName)) { phase in
                                switch phase {
                                case .empty:
                                    // Placeholder image or view
                                    Image(systemName: "photo")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 100, height: 100)
                                case .success(let image):
                                    // Successfully loaded image
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 100, height: 100)
                                case .failure:
                                    // Failed to load image
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(.red)
                                        .frame(width: 100, height: 100)
                                @unknown default:
                                    // Placeholder image or view for unknown state
                                    Image(systemName: "photo")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 100, height: 100)
                                }
                            }
                            .padding(10)
                            VStack {
                                Text(music.trackName)
                                    .font(.headline)
                                    .padding(.top, 8)
                                
                                Text(music.artistName)
                                    .font(.subheadline)
                                    .padding(.top, 4)
                                
                                
                                
                            }
                            .padding(EdgeInsets(
                                top: 10,
                                leading: 27,
                                bottom: 10,
                                trailing: 27
                            ))
                            
                            
                        }
                    } else {
                        Text("ないよ")
                    }
                    if selectedIndex < viewModel.dates.count {
                        let correspondingDate = viewModel.dates[selectedIndex]
                        Text("日付: \(correspondingDate)")
                            .padding()
                    } else {
                        Text("日付情報なし")
                            .padding()
                    }
                    
                    
                }
                .onDisappear{
                    viewModel.stop()
                }
                
                
                .onAppear {
                    Task {
                        do {
                            try await viewModel.getDate()
                            try await viewModel.getMusic(documentId: tapdocumentId, folder: viewModel.folderDocument, friendUid: friendUid)
                        
                        } catch {
                            print("テキスト情報の取得に失敗しました: \(error)")
                        }
                    }
                    
                    Task {
                        do {
                      
                        } catch {
                            print("Error loading music: \(error.localizedDescription)")
                        }
                    }
                }
                .background(Color.white)
                
            }
            .onTapGesture {
                viewModel.startPlay()
                  }
            
        }
        
        
    }
    
    
}
