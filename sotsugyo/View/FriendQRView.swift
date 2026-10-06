//
//  FriendQRView.swift
//  sotsugyo
//
//  Created by saki on 2023/12/18.
//

import SwiftUI
import FirebaseAuth
import CodeScanner

struct FriendQRView: View {
    @Binding var isPresentingCamera: Bool
    @StateObject var cameraManager: CameraManager
    @StateObject private var viewModel = FriendQRViewModel()
    @Environment(\.dismiss) private var dismiss
    @Binding var isPresentingQR: Bool
    @State var isPresentingQRCode =  false
    
    @State private var isPresentingScanner = false
    @State private var qrCodeImage: UIImage?
    @State var friendUid: String
    private let qrCodeGenerator = QRCodeGenerator()
    
    var body: some View {
        
        
        VStack {
            if let qrCodeImage {
                Image(uiImage: qrCodeImage)
                    .resizable()
                    .frame(width: 200, height: 200)
            }
            Button("QRコードを読み取る") {
                
                isPresentingScanner.toggle()
                
            }
            .sheet(isPresented: $isPresentingScanner) {
                CodeScannerView(codeTypes: [.qr], simulatedData: "Simulated QR Code") { result in
                    handleScanResult(result)
                }
            }
            .alert(isPresented: $viewModel.showAlert) {
                Alert(
                    title: Text(viewModel.confirmedUserID == nil ? "読み取れませんでした" : "相手を確認しました"),
                    message: Text(viewModel.alertMessage),
                    dismissButton: .default(Text("OK")){
                        
                        if viewModel.confirmedUserID != nil {
                            isPresentingQRCode = true
                        }
                        
                    }
                )
            }
            .fullScreenCover(isPresented: $isPresentingQRCode) {
                
                CameraView(isPresentingCamera: $isPresentingQRCode, cameraManager: cameraManager, isPresentingSearch: .constant(true),friendUid: $friendUid)
                
            }
            .onChange(of: isPresentingQRCode) { oldValue, newValue in
                if oldValue && !newValue {
                    isPresentingQR = false
                }
            }
            
            
            
        }
        .onAppear{
            if let currentUser = Auth.auth().currentUser {
                let uid = currentUser.uid
                qrCodeImage = qrCodeGenerator.generate(with: uid)
            }
        }
        
    }
    
    private func handleScanResult(_ result: Result<CodeScanner.ScanResult, CodeScanner.ScanError>) {
        switch result {
        case .success(let scanResult):
            isPresentingScanner = false

            Task {
                if let uid = await viewModel.loadFriendProfile(uid: scanResult.string) {
                    friendUid = uid
                }
            }
        case .failure(let error):
            isPresentingScanner = false
            viewModel.reportScanFailure(error)
        }
    }
}



