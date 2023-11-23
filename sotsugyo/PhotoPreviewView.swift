import SwiftUI


struct PhotoPreviewView: View {
    let image: UIImage?
    @Binding var isPresentingCamera: Bool
    @ObservedObject var cameraManager: CameraManager
    let previewX = CGFloat(27)
    let previewY = CGFloat(131)
    let previewWidth = UIScreen.main.bounds.width * 0.867
    let previewHeight = UIScreen.main.bounds.height * 0.537
    
    var body: some View {
        VStack {
            if let image = image {
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
                        DrawingContentView()
                    }
                Button("保存") {
                    cameraManager.uploadPhoto(image)
                    isPresentingCamera = false
                }
                .padding()
            } else {
                Text("写真がありません")
            }
        }
        .background(Color.yellow)
    }
}
