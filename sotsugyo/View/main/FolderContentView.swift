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

    var body: some View {
        ScrollView(.horizontal) {
            HStack {
                ForEach(viewModel.folders.indices, id: \.self) { folderIndex in
                    Button {
                        selectedFolderIndex = folderIndex
                        print(selectedFolderIndex,viewModel.getimage)
                       
                        Task {
                            do {
                               
                                if selectedFolderIndex == folderIndex {
                                   
                                    viewModel.getimage.toggle()
                                }
                            }
                        }

                      
                    } label: {
                        Text(viewModel.folders[folderIndex] as! String)
                    }
                    .padding()
                    .background(selectedFolderIndex == folderIndex ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
    }
}
