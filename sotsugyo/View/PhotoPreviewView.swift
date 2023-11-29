import SwiftUI


struct PhotoPreviewView: View {
    var images: UIImage?
    @Binding var isPresentingCamera: Bool
    @ObservedObject var cameraManager: CameraManager
    let previewX = CGFloat(27)
    let previewY = CGFloat(131)
    let previewWidth = UIScreen.main.bounds.width * 0.867
    let previewHeight = UIScreen.main.bounds.height * 0.537
    @Environment(\.displayScale) private var displayScale
    @Environment(\.dismiss) var dismiss
  
    @StateObject private var viewModel = PhotoPreviewViewModel()
    var body: some View {
        VStack {
            if let image = images {
                
                Button("保存") {
                    viewModel.takeScreenshot()
                    //       if let capture = UIApplication.shared.windows.first?.rootViewController?.view.snapshot {
                    
                    UIImageWriteToSavedPhotosAlbum(viewModel.screenshotImage ?? image, nil, nil, nil)
                    cameraManager.uploadPhoto(viewModel.screenshotImage ?? image)
                    
                    isPresentingCamera = false
                    dismiss()
                   
                    
                }
                .padding()
                Image("Image")
                    .resizable()
                    .scaledToFit()
                
                    .overlay {
                        Image(uiImage: image)
                            .resizable()
                        
                            .frame(width: previewWidth ,height: previewHeight)
                            .position(x: 195, y: 286)
                    }
                    .overlay{
                        PencilView()
                    }
                
            } else {
                Text("写真がありません")
            }
        }
        .background(Color.yellow)
    }
   

    
}


