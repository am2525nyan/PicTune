import SwiftUI

struct Camera2View: View {
    @Binding var isPresentingCamera: Bool
   
    @ObservedObject var cameraManager: CameraManager
    @Environment(\.presentationMode) var presentation
    @State private var isPresentingMain = false
    @State var isPresentingSearch =  false
   
    
    
    
    
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
                
                .sheet(isPresented: $cameraManager.isImageUploadCompleted) {
                    PhotoPreviewView(images: cameraManager.newImage, isPresentingCamera: $isPresentingCamera, isPresentingSearch: $isPresentingSearch, documentId: $cameraManager.documentId, cameraManager: cameraManager)
    
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
