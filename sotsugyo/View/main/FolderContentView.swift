//
//  FolderContentView.swift
//  sotsugyo
//
//  Created by saki on 2023/12/16.
//

import SwiftUI

struct FolderContentView: View {
    @ObservedObject var viewModel: MainContentModel
    @Binding var selectedFolderIndex: Int
    @State var selectedFolderIndex2: Int = 0
    
    var body: some View {
        ScrollView(.horizontal) {
            HStack {
                ForEach(viewModel.folders.indices, id: \.self) { folderIndex in
                    Button {
                        selectedFolderIndex = folderIndex
                        selectedFolderIndex2 = folderIndex
                        Task {
                            do {
                                
                                if selectedFolderIndex == folderIndex {
                                    
                                    viewModel.getimage.toggle()
                                }
                            }
                        }
                        
                        
                    } label: {
                        Text(viewModel.folders[folderIndex] )
                        
                            .font(.system(size: 12))
                    }
                    .padding()
                    .background(selectedFolderIndex2 == folderIndex ? 
                                
                                Color(red: 0.741, green: 0.584, blue: 0.933, opacity: 1) : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    
                    .background(.ultraThinMaterial)
                    .cornerRadius(6)
                    
                }
            }
        }
        
    }
}
