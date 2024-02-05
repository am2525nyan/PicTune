//
//  FolderTextView.swift
//  sotsugyo
//
//  Created by saki on 2023/12/16.
//

import SwiftUI
import FirebaseAuth
import SwiftyGif
import UIKit

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
    @State var playGif = true
    @State var isActive: Bool = false
    @State var isdeletefolder = false
    var gif = UIImageView()
    let gifData = NSDataAsset(name:"heart3")?.data
    let gifData2 = NSDataAsset(name:"fun")?.data
    var body: some View {

        VStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .center, spacing: 0) {
                    HStack(alignment: .center, spacing: 0) {
                        
                        
                        VStack(alignment: .leading, spacing: 0) {
                            if viewModel.folders.indices.contains(selectedFolderIndex) {
                            } else {
                                ZStack{
                                    
                                    if let gifData = gifData {
                                        GIFImage(data: gifData)
                                            .frame(height: 100)
                                    }
                                    Text("読み込み中")
                                        .font(.custom("Roboto", size: 14))
                                        .foregroundColor(Color(red: 0, green: 0, blue: 0))
                                }
                            }
                            
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity)
                }
                //    .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                HStack(alignment: .top, spacing: 8) {
                    if viewModel.folders.indices.contains(selectedFolderIndex) {
                        if viewModel.folders[selectedFolderIndex] != "all"{
                            VStack(alignment: .center, spacing: 0) {
                                Button {
                                    isdeletefolder.toggle()
                                    
                                } label: {
                                    Text("フォルダ削除")
                                        .font(.custom("Roboto", size: 16))
                                        .foregroundColor(Color(red: 0, green: 0, blue: 0))
                                        .frame(width: 120, height: 30)
                                    
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 10)
                                        .frame(maxWidth: .infinity)
                                        .background(Color(red: 0.902, green:  0.882, blue: 0.922))
                                        .cornerRadius(8)
                                    
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke()
                                                .foregroundStyle(
                                                    .linearGradient(
                                                        colors: [.white.opacity(0.5), .clear],
                                                        startPoint: .top,
                                                        endPoint: .bottom
                                                    )
                                                )
                                        )
                                        .shadow(color: .black.opacity(0.3), radius: 5, y: 3)
                                }
                                
                                .alert("フォルダ削除", isPresented: $isdeletefolder) {
                                    Button("OK", role: .destructive){
                                        viewModel.deletefolder()
                                    }
                                    
                                } message: {
                                    Text("このフォルダを削除しますか？")
                                }
                            }
                            
                        }
                        
                        
                    }
                    
                    if viewModel.folders.indices.contains(selectedFolderIndex) {
                        VStack(alignment: .center, spacing: 0) {
                            
                            Button {
                                viewModel.getLetter()
                                isWrite = true
                                
                            } label: {
                                Text("手紙を見る/書く")
                                    .font(.custom("Roboto", size: 13))
                                    .foregroundColor(Color(red: 1, green: 1, blue: 1))
                                    .frame(width: 120, height: 30)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity)
                                    .background(Color(red: 0, green: 0, blue: 0))
                                    .cornerRadius(8)
                                
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke()
                                            .foregroundStyle(
                                                .linearGradient(
                                                    colors: [.white.opacity(0.5), .clear],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                    )
                                    .shadow(color: .black.opacity(0.3), radius: 5, y: 3)
                                
                            }
            //                .popoverTip(LetterTip())
                        }
                        
                    }
                    
                }
                
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.vertical, 10)
                if viewModel.folders.indices.contains(selectedFolderIndex) {
                    HStack(alignment: .top, spacing: 8) {
                        
                        VStack(alignment: .center, spacing: 4) {
                            
                            Button {
                                isNFC .toggle()
                            } label: {
                                Text("NFCにフォルダを保存")
                                    .font(.custom("Roboto", size: 12))
                                    .foregroundColor(Color(red: 0, green: 0, blue: 0))
                                    .frame(width: 240, height: 20)
                                    .padding(.all, 8)
                                    .frame(maxWidth: .infinity, alignment: .top)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(6)
                                
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke()
                                            .foregroundStyle(
                                                .linearGradient(
                                                    colors: [.white.opacity(0.5), .clear],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                    )
                                    .shadow(color: .black.opacity(0.3), radius: 5, y: 3)
                                
                            }
                         //   .popoverTip(PostNFCTip())
                            
                            
                            .alert("NFCに保存", isPresented: $isNFC) {
                                
                                Button("OK"){
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
                                Button("cancel",role:.cancel){
                                    
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
                    
                }
                
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 15)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .sheet(isPresented: $isWrite){
            WriteLetterView(isWrite: $isWrite, viewModel: viewModel, userDataList: userDataList)
        }
        
    }
    
}


