import SwiftUI

struct Camera2View: View {
    @Binding var isPresentingCamera: Bool
   
    @ObservedObject var cameraManager: CameraManager
    @Environment(\.presentationMode) var presentation
    @State private var isPresentingMain = false
    @Binding var isPresentingSearch : Bool
   
    @Environment(\.dismiss) var dismiss
    
    
    
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
                .onChange(of: cameraManager.isImageUploadCompleted) {
                    
                }
                
                .sheet(isPresented: $cameraManager.isImageUploadCompleted, onDismiss: {
                    dismiss()
                 }) {
                    PhotoPreviewView(images: cameraManager.newImage, isPresentingCamera: $isPresentingCamera, isPresentingSearch: $cameraManager.isPresentingSearch, documentId: $cameraManager.documentId, cameraManager: cameraManager)
    
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
