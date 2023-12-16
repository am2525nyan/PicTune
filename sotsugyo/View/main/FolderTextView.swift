//
//  FolderTextView.swift
//  sotsugyo
//
//  Created by saki on 2023/12/16.
//

import SwiftUI

struct FolderTextView: View {
    @ObservedObject var viewModel: MainContentModel
    @Binding var selectedFolderIndex: Int
    @ObservedObject var userDataList: MainContentModel
    @State var isWrite = false
    var body: some View {
        VStack{
            HStack {
                
                if viewModel.folders.indices.contains(selectedFolderIndex) {
                    Text(viewModel.folders[selectedFolderIndex])
                        .padding()
                        .font(.system(size: 25))
                } else {
                    Text("読み込み中")
                }
                Button {
                    isWrite = true
                } label: {
                    Text("+")
                        .frame(width: 50, height: 50)
                        .font(.system(size: 25))
                }
                .background(.white)
                .cornerRadius(8)
               
                
                
            }
           
            Text(userDataList.userDataList)
            
        }
        .sheet(isPresented: $isWrite){
            WriteLetterView(isWrite: $isWrite, viewModel: viewModel, userDataList: userDataList)
        }
        .onAppear{
            
           

        }
        
    }
    
    func printValues() {
        print(viewModel.folders, selectedFolderIndex)
    }
}
