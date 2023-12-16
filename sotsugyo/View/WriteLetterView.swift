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
            TextField("Enter text", text: $userInput)
                .padding()
            
            Button("Save") {
                userDataList.userDataList = userInput
                viewModel.saveLetter()
                           // シートを閉じる
                           isWrite = false
                           userInput = ""
                
            }
            .padding()
        }
    }

    
}
