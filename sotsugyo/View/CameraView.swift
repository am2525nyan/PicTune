import SwiftUI


struct CameraView: View {
    @Binding var isPresentingCamera: Bool
    
    @ObservedObject var cameraManager: CameraManager
    @Environment(\.presentationMode) var presentation
    @State private var isPresentingMain = false
    @Binding var isPresentingSearch : Bool
    @Binding var friendUid: String
    @Environment(\.dismiss) private var dismiss

    let previewWidth = UIScreen.main.bounds.width * 0.864
    let previewHeight = UIScreen.main.bounds.height * 0.6
    
    @StateObject private var viewModel = MainContentModel()
    @StateObject private var color = ColorModel()
    
    let previewWidth2 = UIScreen.main.bounds.width * 0.8
    let previewHeight2 = UIScreen.main.bounds.height * 0.497
    
   
    var body: some View {
        NavigationView {
            ZStack {
                
                color.backGroundColor().edgesIgnoringSafeArea(.all)
                GeometryReader { geometry in
                    ZStack {
                        // CameraPreview
                        CameraPreview(cameraManager: cameraManager)
                        
                            .frame(width: geometry.size.width, height: geometry.size.height)
                        
                        // Image
                        Image("Image")
                            .resizable()
                            .scaledToFit()
                            .padding(.bottom, 70)
                            .frame(width: 375, height: 603)
                            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                       
                    }
                }
                
                
                VStack {
                    Spacer()
                    Button {
                        cameraManager.captureImage()
                    } label: {
                        Image("CameraButton")
                            .resizable()
                            .frame(width: 75,height: 75)
                        
                    }
                    
                    
                    
                    .sheet(isPresented: $cameraManager.isImageUploadCompleted) {
                        
                        PhotoPreviewView(images: cameraManager.newImage, isPresentingCamera: $isPresentingCamera, isPresentingSearch: $cameraManager.isPresentingSearch, documentId: $cameraManager.documentId, cameraManager: cameraManager, friendUid: $friendUid)
                        
                    }
                    
                }
                .padding(.bottom,  30)
            }
            .navigationBarItems(leading: Button(action: {
                dismiss()
                
            }) {
                Image(systemName: "arrow.left")
                    .foregroundColor(.blue)
            })
            
            .onAppear {
                cameraManager.setupCaptureSession()
               
                Task{
                    await SettingTip.openCamera.donate()
                }
            }
            .onDisappear {
                cameraManager.stopSession()
            }
            .edgesIgnoringSafeArea(.all)
            
            
        }
        
    }

    
}
extension View {
    // 発光エフェクトを追加する拡張
    func glow(radius: CGFloat = 10.0, color: Color = .blue) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color, lineWidth: 2)
                .blur(radius: radius)
                .offset(x: 0, y: 0)
                .opacity(0.7)
        )
    }
}

#Preview {
    CameraView(isPresentingCamera: .constant(true), cameraManager: CameraManager(), isPresentingSearch: .constant(false), friendUid: .constant("nil"))
}


