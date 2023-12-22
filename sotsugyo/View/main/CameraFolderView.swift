//
//  CameraFolderView.swift
//  sotsugyo
//
//  Created by saki on 2023/12/16.
//

import SwiftUI
import CoreNFC

struct CameraFolderView: View {
    @Binding var isPresentingCamera: Bool
    @Binding var showAlart: Bool
    @Binding var folderBuf: String
    @StateObject  var session = NFCSession()
    @StateObject var cameraManager: CameraManager
    @ObservedObject var viewModel: MainContentModel
    @State var showQRAlart = false
    @State var isPresentingQR = false
    @Binding var friendUid: String
    @State var isAlertShown = false
      @State  var alertMessage = ""
 var textPayload2: NFCNDEFPayload?
    var body: some View {
        HStack {
         
                Button("カメラを開く") {
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
        // ボタンでの読み込み処理
        Button("読み込み") {
            // ボタンが押されたときに一度だけ読み取りセッションを開始
            session.startReadSession { text, NFCUid, error in
                if let error = error {
                    alertMessage = error.localizedDescription
                } else {
                    alertMessage = "読み込みできたよ"
                    
                    if let NFCUid = NFCUid {
                        // 改行文字以降を削除
                        if let cleanedNFCUid = NFCUid.components(separatedBy: "\n").first {
                            // text をアンラップ
                            if let unwrappedText = text {
                                Task {
                                    // viewModel.getNFCDataを呼び出す
                                    do {
                                        print(cleanedNFCUid as Any, "C")
                                        print(unwrappedText as Any, "D")
                                        try await viewModel.getNFCData(NFCUid: cleanedNFCUid, NFCfolderid: unwrappedText)
                                       
                                    } catch {
                                        // エラーのハンドリング
                                        print("Error: \(error)")
                                    }
                                    
                                    // ハンドラに渡す
                                    session.readHandler?(unwrappedText, cleanedNFCUid, nil)
                                }
                            }
                        }
                    }
                }
                isAlertShown = true
            }
        }

        .alert(isPresented: $isAlertShown) {
                    Alert(
                        title: Text(""),
                        message: Text(alertMessage),
                        dismissButton: .default(Text("OK")))
                }
            .fullScreenCover(isPresented: $isPresentingCamera) {
                Camera2View(isPresentingCamera: $isPresentingCamera, cameraManager: cameraManager, isPresentingSearch: .constant(true), friendUid: .constant(""))
            }
            .sheet(isPresented: $isPresentingQR){
                FriendQRView(isPresentingCamera: $isPresentingCamera, cameraManager: cameraManager, friendUid:"")
                
            }
        
    }
}

