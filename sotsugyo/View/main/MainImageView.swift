//
//  MainImageView.swift
//  sotsugyo
//
//  Created by saki on 2023/12/16.
//

import SwiftUI
struct MainImageView: View {
    @Binding var tapImage: UIImage?
    @Binding var tapIndex: Int
    @Binding var tapdocumentId: String
    @Binding var selectedFolderIndex: String
    
    @ObservedObject var viewModel: MainContentModel
    
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 3) {
                ForEach($viewModel.images.indices, id: \.self) { index in
                    
                    imageCell(index: index, selectedFolderIndex: $tapIndex)
                }
            }
        }
        .refreshable {
            Task {
                do {
                    try await viewModel.FoldergetUrl(folderId: tapIndex)
                }
            }
        }
        .onChange(of: viewModel.getimage) {
            Task {
                do {
                    try await viewModel.FoldergetUrl(folderId: tapIndex)
                    
                    
                    
                    
                } catch {
                    print("Error: \(error)")
                }
            }
        }
    }
    
    
    private func imageCell(index: Int, selectedFolderIndex: Binding<Int>) -> some View {
        
        
        return NavigationLink(
            destination: ImageDetailView(image: $tapImage, documentId: $tapdocumentId, tapdocumentId: $tapdocumentId, index: selectedFolderIndex, viewModel: viewModel, friendUid: .constant(""), selectedIndex: tapIndex),
            tag: viewModel.images[index],
            selection: $tapImage,
            label: {
                Image(uiImage: viewModel.images[index])
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180, height: 315)
                    .clipped()
                    .onTapGesture {
                        tapdocumentId = viewModel.documentIdArray[index]
                        tapImage = viewModel.images[index]
                        tapIndex = index
                    }
                    .contextMenu {
                        ForEach(viewModel.folders.indices, id: \.self) { index1 in
                            Button {
                                viewModel.appendFolder(folderId: index1, index: index)
                            } label: {
                                Text(viewModel.folders[index1] )
                            }
                            
                            
                        }
                        
                        
                        Button("削除", role: .destructive) {
                            let intValue = selectedFolderIndex.wrappedValue
                            viewModel.deletePhoto(document: viewModel.documentIdArray[index])
                            Task {
                                do {
                                    try await viewModel.FoldergetUrl(folderId: intValue)
                                    try await viewModel.getUrl()
                                } catch {
                                    print("Error: \(error)")
                                }
                            }
                            
                            
                        }
                        
                        
                    }
            }
            
        )
        
    }
}

