import SwiftUI
import ARKit

struct CameraView: View {
    @Binding var isPresentingCamera: Bool
    
    @ObservedObject var cameraManager: CameraManager
    @Environment(\.presentationMode) var presentation
    @State private var isPresentingMain = false
    @Binding var isPresentingSearch : Bool
    @Binding var friendUid: String
    @Environment(\.dismiss) private var dismiss
    @State private var laughingmanNode: SCNReferenceNode?
    let previewWidth = UIScreen.main.bounds.width * 0.864
    let previewHeight = UIScreen.main.bounds.height * 0.6
    @State private var faceGeometry: ARSCNFaceGeometry? = ARSCNFaceGeometry()
    @StateObject private var viewModel = MainContentModel()
    @StateObject private var color = ColorModel()
  
    let previewWidth2 = UIScreen.main.bounds.width * 0.8
    let previewHeight2 = UIScreen.main.bounds.height * 0.497
    
    let safeAreaInsets: UIEdgeInsets = UIApplication.shared.windows.first?.safeAreaInsets ?? .zero
    
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
                                    .opacity(0.5)
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
                .padding(.bottom,  10)
            }
            .navigationBarItems(leading: Button(action: {
                dismiss()
                
            }) {
                Image(systemName: "arrow.left")
            })
            
            .onAppear {
                cameraManager.setupCaptureSession()
                resetTracking()
            }
            .onDisappear {
                cameraManager.stopSession()
            }
            .edgesIgnoringSafeArea(.all)
            
            
        }
        
    }
    func resetTracking() {
        guard ARFaceTrackingConfiguration.isSupported else {
            // Face tracking is not supported.
            return
        }
        
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        let options: ARSession.RunOptions = [.resetTracking, .removeExistingAnchors]
        
        // laughingmanNodeを初期化
        let path = Bundle.main.path(forResource: "filter", ofType: "scn")!
        let url = URL(fileURLWithPath: path)
        laughingmanNode = SCNReferenceNode(url: url)
        
        
    }
  
}
#Preview {
    CameraView(isPresentingCamera: .constant(true), cameraManager: CameraManager(), isPresentingSearch: .constant(false), friendUid: .constant("nil"))
}


