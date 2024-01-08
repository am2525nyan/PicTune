import SwiftUI
import ARKit

struct Camera2View: View {
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
    
    var body: some View {
        NavigationView {
            ZStack {
                
                
                
                ZStack {
                    // Display the camera preview
              CameraPreview(cameraManager: cameraManager)
                    /*      ARFaceView()
                        .frame(width: previewWidth, height: previewHeight)
                    
                    // Display the ARFaceTrackingView
                                ARFaceTrackingView(faceGeometry: $faceGeometry)
                     .frame(width: previewWidth, height: previewHeight)
                     .onAppear {
                     // Ensure faceGeometry is initialized with a non-nil value
                     if faceGeometry == nil {
                     faceGeometry = ARSCNFaceGeometry()
                     }
                     }
                     */
                }
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
            .navigationBarItems(leading: Button(action: {
              dismiss()
                
            }) {
                Image(systemName: "arrow.left")
            })
            .background(Color.yellow)
            .onAppear {
                
                cameraManager.setupCaptureSession()
                resetTracking()
            }
            .onDisappear {
                
                cameraManager.stopSession()
            }
            
            
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
