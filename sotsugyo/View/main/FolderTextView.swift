//
//  FolderTextView.swift
//  sotsugyo
//
//  Created by saki on 2023/12/16.
//

import SwiftUI
import FirebaseAuth

struct FolderTextView: View {
    @ObservedObject var viewModel: MainContentModel
    @StateObject private var session = NFCSession()
    @Binding var selectedFolderIndex: Int
    @ObservedObject var userDataList: MainContentModel
    @State var isWrite = false
    @State var isNFC = false
    @State private var isAlertShown = false
    @State private var alertMessage = ""
    @Binding var folderDocument: String
    
    var body: some View {
        VStack{
            HStack {
                
                if viewModel.folders.indices.contains(selectedFolderIndex) {
                    Text(viewModel.folders[selectedFolderIndex])
                        .padding()
                        .font(.system(size: 17))
                } else {
                    Text("読み込み中")
                }
                if viewModel.folders.indices.contains(selectedFolderIndex) {
                    Button {
                        isWrite = true
                    } label: {
                        Text("+")
                            .frame(width: 50, height: 50)
                            .font(.system(size: 17))
                    }
                    
                    .background(.white)
                    .cornerRadius(8)
                }
                if viewModel.folders.indices.contains(selectedFolderIndex) {
                    
                    
                    if viewModel.folders[selectedFolderIndex] != "all"{
                        Button {
                            viewModel.deletefolder()
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                
                                
                            }
                            .frame(width: 50, height: 50)
                            .font(.system(size: 17))
                        }
                    }else{
                        
                    }
                }
                if viewModel.folders.indices.contains(selectedFolderIndex) {
                    Button {
                        isNFC .toggle()
                    } label: {
                        Text("♡")
                            .frame(width: 50, height: 50)
                            .font(.system(size: 17))
                    }
                    
                    .background(.white)
                    .cornerRadius(8)
                    .alert("コード交換", isPresented: $isNFC) {
                        
                        Button("する", role: .cancel){
                            if let currentUser = Auth.auth().currentUser {
                                let uid = currentUser.uid
                            session.startWriteSession(UserUid: uid, folder: folderDocument) { error in
                                if let error = error {
                                    alertMessage = error.localizedDescription
                                    isAlertShown = true
                                }
                                }
                            }
                        }
                        Button("しない", role: .destructive){
                            isNFC.toggle()
                        }
                    } message: {
                        Text("このフォルダをNFCカードに入れますか？")
                    }
                    .alert(isPresented: $isAlertShown) {
                        Alert(
                            title: Text(""),
                            message: Text(alertMessage),
                            dismissButton: .default(Text("OK")))
                    }
                }
            }
            
            Text(userDataList.userDataList)
            
        }
        .sheet(isPresented: $isWrite){
            WriteLetterView(isWrite: $isWrite, viewModel: viewModel, userDataList: userDataList)
        }
        .onAppear{
            
            
            
        }
        
    }
    
}
