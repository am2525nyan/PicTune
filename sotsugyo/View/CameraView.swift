import SwiftUI

struct Camera2View: View {
    @Binding var isPresentingCamera: Bool
    
    @ObservedObject var cameraManager: CameraManager
    @Environment(\.presentationMode) var presentation
    @State private var isPresentingMain = false
    @Binding var isPresentingSearch : Bool
    @Binding var friendUid: String
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {

        ZStack {
            
            
            CameraPreview(cameraManager: cameraManager)
            Image("Image")
                .resizable()
                .scaledToFit()
            
            VStack {
                Spacer()
                Button("撮影") {
                    cameraManager.captureImage()
                }
                
                .padding()
                
                .sheet(isPresented: $cameraManager.isImageUploadCompleted) {
                    
                    
                    PhotoPreviewView(images: cameraManager.newImage, isPresentingCamera: $isPresentingCamera, isPresentingSearch: $cameraManager.isPresentingSearch, documentId: $cameraManager.documentId, cameraManager: cameraManager, friendUid: $friendUid)
                    
                }
            }
            
        }
        .background(Color.yellow)
        .onAppear {
            
            cameraManager.setupCaptureSession()
        }
        .onDisappear {
            
            cameraManager.stopSession()
        }
    }
}
