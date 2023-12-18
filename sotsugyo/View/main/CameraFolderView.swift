//
//  CameraFolderView.swift
//  sotsugyo
//
//  Created by saki on 2023/12/16.
//

import SwiftUI

struct CameraFolderView: View {
    @Binding var isPresentingCamera: Bool
    @Binding var showAlart: Bool
    @Binding var folderBuf: String
    @StateObject var cameraManager: CameraManager
    @ObservedObject var viewModel: MainContentModel
    @State var showQRAlart = false
    @State var isPresentingQR = false
    @Binding var friendUid: String

    var body: some View {
        HStack {
            Button("カメラ起動") {
                showQRAlart.toggle()
            }
            .alert("コード交換", isPresented: $showQRAlart) {
               
                Button("する", role: .cancel){
                    isPresentingQR.toggle()
                    
             
                }
                Button("しない", role: .destructive){
                    isPresentingCamera.toggle()
                }
            } message: {
                Text("一緒のお友達のコードを読み込みますか？")
            }
            Button("フォルダ作成") {
                showAlart = true
            }
            .alert("フォルダを制作", isPresented: $showAlart) {
                TextField("フォルダ名", text: $folderBuf)
                Button("OK", role: .cancel){
                    viewModel.makeFolder(folderName: folderBuf)
                    folderBuf = ""
                    showAlart = false
                
                }
                Button("Cancel", role: .destructive){
                }
            } message: {
                Text("フォルダ名を入力")
            }
        }
        .fullScreenCover(isPresented: $isPresentingCamera) {
            Camera2View(isPresentingCamera: $isPresentingCamera, cameraManager: cameraManager, isPresentingSearch: .constant(true), friendUid: .constant(""))
        }
        .sheet(isPresented: $isPresentingQR){
            FriendQRView(isPresentingCamera: $isPresentingCamera, cameraManager: cameraManager, friendUid:"")
            
        }
    }
}

