//
//  FriendQRView.swift
//  sotsugyo
//
//  Created by saki on 2023/12/18.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import CodeScanner

struct FriendQRView: View {
    @Binding var isPresentingCamera: Bool
    @StateObject var cameraManager: CameraManager
    @Environment(\.dismiss) private var dismiss
    @State private var isPresentingQR = false
    
    @State private var isPresentingScanner = false
    @State private var scannedCode: String?
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    @State private var qrCodeImage: UIImage?
       private let qrCodeGenerator = QRCodeGenerator()
    
    var body: some View {
        
        
        Button("カメラ起動") {
            dismiss()
        }
        
        
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
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("相手を確認しました"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK")){
                        isPresentingQR = true
                    }
                )
            }
            .fullScreenCover(isPresented: $isPresentingQR) {
                       // isPresentingQRがtrueのときにフルスクリーンでCamera2Viewを開く
                Camera2View(isPresentingCamera: $isPresentingCamera, cameraManager: cameraManager, isPresentingSearch: .constant(true))
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
            scannedCode = scanResult.string
            isPresentingScanner = false
            getUserInfo(uid: scannedCode!)
        case .failure(let error):
            if let scanError = error as? CodeScanner.ScanError {
                print("Scanning failed with error: \(scanError)")
            } else {
                print("Scanning failed with unknown error")
            }
            // Handle error as needed
        }
    }
    
  
    private func getUserInfo(uid: String) {
        let db = Firestore.firestore()
        db.collection("users").document(uid).collection("personal").document("info").getDocument { document, error in
            if let error = error {
                print("Error getting user info: \(error.localizedDescription)")
                showAlert(message: "Error getting user info")
                return
            }
            
            if let document = document, document.exists {
                if let name = document["name"] as? String {
                    showAlert(message: " \(name)さんと撮ります")
                } else {
                    showAlert(message: "User info is incomplete")
                }
            } else {
                showAlert(message: "User info not found")
            }
        }
    }
    
    private func showAlert(message: String) {
        alertMessage = message
        showAlert = true
    }
}





