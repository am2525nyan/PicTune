import SwiftUI

struct Camera2View: View {
    @Binding var isPresentingCamera: Bool
    @ObservedObject var cameraManager: CameraManager
    @Environment(\.presentationMode) var presentation
    @State private var isPresentingMain = false
    
    init(isPresentingCamera: Binding<Bool>, cameraManager: CameraManager) {
        self._isPresentingCamera = isPresentingCamera
        self.cameraManager = cameraManager
        self.cameraManager.setupCaptureSession()
    }
    
    
    
    
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
                    PhotoPreviewView(image: cameraManager.newImage, isPresentingCamera: $isPresentingCamera, cameraManager: cameraManager)
                  
                    
                }
            }
            
        }
        .background(Color.yellow)
        .onAppear {
            cameraManager.startSession()
           
        }
        .onDisappear {
            
            
            
     //       cameraManager.stopSession()
        }
    }
}
