//
//  ButtonView.swift
//  sotsugyo
//
//  Created by saki on 2024/01/09.
//

import SwiftUI

struct ButtonView: View {
    @ObservedObject var viewModel: MainContentModel
    @StateObject  var session = NFCSession()
    @StateObject var cameraManager: CameraManager
    @Binding  var selectedImage: UIImage?
    @Binding  var selectedIndex: Int
    @Binding  var tapDocumentId: String
    @Binding  var showAlart: Bool
    @Binding  var folderBuf: String
    @Binding var selectedFolderIndex: Int
    
    @Binding var isPresentingCamera: Bool
    @Binding var showQRAlart: Bool
    @Binding var isPresentingQR: Bool
    
    @State var isAlertShown = false
    @State  var alertMessage = ""
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .center, spacing: 4) {
                Button {
                    showQRAlart.toggle()
                } label: {
                    VStack(alignment: .center, spacing: 4) {
                        
                        ZStack {
                            Text("📸")
                                .font(.custom("Roboto", size: 30))
                                .foregroundColor(Color(red: 0, green: 0, blue: 0))
                        }
                        .background(Color(red: 0, green: 0, blue: 0, opacity: 0.05))
                        .cornerRadius(24)
                        Text("撮影")
                            .font(.custom("Roboto", size: 10))
                            .foregroundColor(Color(red: 0, green: 0, blue: 0))
                        
                    }
                    .padding(.all, 4)
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
                
                .popoverTip(CameraTip())
                
                
                
                
                
                .alert("コード交換", isPresented: $showQRAlart) {
                    Button("しない", role: .destructive){
                        isPresentingCamera.toggle()
                    }
                    Button("する", role: .cancel){
                        isPresentingQR.toggle()
                        
                    }
                    
                } message: {
                    Text("一緒のお友達のコードを読み込みますか？")
                }
                
            } 
            VStack(alignment: .center, spacing: 4) {
                
                Button {
                    showAlart = true
                } label: {
                    VStack(alignment: .center, spacing: 4) {
                        ZStack {
                            Text("📁")
                                .font(.custom("Roboto", size: 30))
                                .foregroundColor(Color(red: 0, green: 0, blue: 0))
                        }
                        .background(Color(red: 0, green: 0, blue: 0, opacity: 0.05))
                        .cornerRadius(24)
                        Text("フォルダ作成")
                            .font(.custom("Roboto", size: 10))
                            .foregroundColor(Color(red: 0, green: 0, blue: 0))
                        
                    }
                    .padding(.all, 4)
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
                .alert("フォルダを作成", isPresented: $showAlart) {
                    TextField("フォルダ名", text: $folderBuf)
                    Button("OK"){
                        viewModel.makeFolder(folderName: folderBuf)
                        folderBuf = ""
                        showAlart = false
                        
                    }
                    Button("Cancel", role: .cancel){
                    }
                } message: {
                    Text("フォルダ名を入力")
                }
            }
            
            VStack(alignment: .center, spacing: 4) {
                Button {
                    startNFCReadSession()
                } label: {
                    VStack(alignment: .center, spacing: 4) {
                        ZStack {
                            Text("⚙️")
                                .font(.custom("Roboto", size: 30))
                                .foregroundColor(Color(red: 0, green: 0, blue: 0))
                            
                        }
                        .background(Color(red: 0, green: 0, blue: 0, opacity: 0.05))
                        .cornerRadius(24)
                        Text("NFC読み込み")
                            .font(.custom("Roboto", size: 10))
                            .foregroundColor(Color(red: 0, green: 0, blue: 0))
                        
                    }
                    .padding(.all, 4)
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
                //      .popoverTip(NFCTip())
                
            }
            
            
        }
        .alert(isPresented: $isAlertShown) {
            Alert(title: Text("NFC読み取り結果"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            
            
            
        }
        
        
        
        
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
    private func startNFCReadSession() {
        viewModel.startAnimation()
        
        
        session.startReadSession { text, NFCUid, error in
            if let error = error {
                alertMessage = error.localizedDescription
            } else {
                alertMessage = "NFC読み取り成功！"
                
                if let NFCUid = NFCUid {
                    // 上記で提供したコードをここに追加
                    if let messageString = NFCUid as? String {
                        // NFCUid が文字列の場合の処理
                        // 例: 文字列を適切に処理する
                        let components = messageString.components(separatedBy: " ")
                        if let cleanedNFCUid = components.first, let unwrappedText = components.last {
                            Task {
                                do {
                                    try await viewModel.getNFCData(NFCUid: cleanedNFCUid, NFCfolderid: unwrappedText)
                                    
                                    //  viewModel.startAnimation()
                                    
                                    
                                } catch {
                                    print("Error: \(error)")
                                }
                            }
                        }
                        
                    }
                }
            }
            
            isAlertShown = true
        }
        viewModel.stopAnimation()
    }
}
