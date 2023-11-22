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
            
     //           .frame(width:120,height: 10)
       //             .position(x: 60,y: 120)
                
            
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
        .onAppear {
        
            cameraManager.startSession()
        }
        .onDisappear {
          
            
           
          cameraManager.stopSession()
        }
    }
}
struct PhotoPreviewView: View {
    let image: UIImage?
        @Binding var isPresentingCamera: Bool
    @ObservedObject var cameraManager: CameraManager

    
    
    var body: some View {
            VStack {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding()

                    Button("保存") {
                        cameraManager.uploadPhoto(image)
                        isPresentingCamera = false
                    }
                    .padding()
                } else {
                    Text("写真がありません")
                }
            }
        }
    }
