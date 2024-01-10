//
//  WriteLetterView.swift
//  sotsugyo
//
//  Created by saki on 2023/12/16.
//

import SwiftUI
struct WriteLetterView: View {
    @State private var userInput = ""
    @Binding var isWrite: Bool
    @ObservedObject var viewModel: MainContentModel
    @ObservedObject var userDataList: MainContentModel
    
    var body: some View {
        VStack {
            TextField("手紙を書く", text: $userInput ,axis: .vertical)
                .lineLimit(0...10)
                .padding()
           
            Button("保存") {
                userDataList.userDataList = userInput
                viewModel.saveLetter()
                // シートを閉じる
                isWrite = false
                userInput = ""
                
            }
            .padding()
        }
        .onAppear{
            if userDataList.userDataList != ""{
                userInput = userDataList.userDataList
            }
        }
    }
    
    
}
