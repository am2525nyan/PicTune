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
                    title: Text("相手を確認しました"),
                    message: Text(viewModel.alertMessage),
                    dismissButton: .default(Text("OK")){
                        
                        isPresentingQRCode.toggle()
                        
                    }
                )
            }
            .fullScreenCover(isPresented: $isPresentingQRCode) {
                
                CameraView(isPresentingCamera: $isPresentingCamera, cameraManager: cameraManager, isPresentingSearch: .constant(true),friendUid: $friendUid)
                
            }
            .onChange(of: isPresentingQRCode) { newValue,_ in
                if newValue {
                    isPresentingQR.toggle()
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
            if let scanError = error as? CodeScanner.ScanError {
                print("Scanning failed with error: \(scanError)")
            } else {
                print("Scanning failed with unknown error")
            }
            // Handle error as needed
        }
    }
}




