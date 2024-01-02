import SwiftUI
import ARKit
import SceneKit

struct PhotoPreviewView: View {
    var images: UIImage?
    @Binding var isPresentingCamera: Bool
    @Binding var isPresentingSearch: Bool
    @Binding var documentId: String
    @ObservedObject var cameraManager: CameraManager
    let previewX = CGFloat(27)
    let previewY = CGFloat(131)
    let previewWidth = UIScreen.main.bounds.width * 0.867
    let previewHeight = UIScreen.main.bounds.height * 0.537
    @Environment(\.displayScale) private var displayScale
    @Binding var friendUid: String
    
    @StateObject private var viewModel = PhotoPreviewViewModel()
    
    var body: some View {
        VStack {
            if let image = images {
                Button("保存") {
                    viewModel.takeScreenshot()
                    UIImageWriteToSavedPhotosAlbum(viewModel.screenshotImage ?? image, nil, nil, nil)
                    cameraManager.uploadPhoto(viewModel.screenshotImage ?? image, friendUid: friendUid)
                }
                .padding()
                
                .sheet(isPresented: $isPresentingSearch) {
                    SearchView(documentId: documentId, friendUid: $friendUid)
                }
                
                Image("Image")
                    .resizable()
                    .scaledToFit()
                    .overlay {
                        Image(uiImage: image)
                            .resizable()
                            .frame(width: previewWidth, height: previewHeight)
                            .position(x: 195, y: 286)
                    }
                    .overlay {
                        PencilView()
                    }
                
            } else {
                Text("写真がありません")
            }
        }
        .background(Color.yellow)
       
    }
}
