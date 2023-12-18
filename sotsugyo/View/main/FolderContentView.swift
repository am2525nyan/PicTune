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
                    }
                    .padding()
                    .background(selectedFolderIndex2 == folderIndex ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    
                    
                    
                }
            }
        }
        
    }
}
