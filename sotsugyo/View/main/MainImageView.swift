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
            destination: ImageDetailView(image: $tapImage, documentId: $tapdocumentId, tapdocumentId: $tapdocumentId, index: selectedFolderIndex, viewModel: viewModel, selectedIndex: tapIndex),
            tag: viewModel.images[index],
            selection: $tapImage,
            label: {
                Image(uiImage: viewModel.images[index])
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 350)
                    .clipped()
                    .onTapGesture {
                        tapdocumentId = viewModel.documentIdArray[index]
                        tapImage = viewModel.images[index]
                        tapIndex = index
                    }
                    .contextMenu {
                        ForEach(viewModel.folders.indices, id: \.self) { index1 in
                            Button {
                                // 更新された引数を渡す
                                viewModel.appendFolder(folderId: index1, index: index)
                            } label: {
                                Text(viewModel.folders[index1] as! String)
                            }
                        }
                    }
            }
            
        )
        
    }
}

