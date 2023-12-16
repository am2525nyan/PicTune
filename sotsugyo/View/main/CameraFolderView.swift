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

    var body: some View {
        HStack {
            Button("カメラ起動") {
                isPresentingCamera = true
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
            Camera2View(isPresentingCamera: $isPresentingCamera, cameraManager: cameraManager, isPresentingSearch: .constant(true))
        }
    }
}

