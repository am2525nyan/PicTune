import SwiftUI


struct PhotoPreviewView: View {
    let image: UIImage?
    @Binding var isPresentingCamera: Bool
    @ObservedObject var cameraManager: CameraManager
    let previewX = CGFloat(27)
    let previewY = CGFloat(131)
    let previewWidth = UIScreen.main.bounds.width * 0.867
    let previewHeight = UIScreen.main.bounds.height * 0.537
    @Environment(\.displayScale) private var displayScale
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack {
            if let image = image {
                
                Button("保存") {
             //       if let capture = UIApplication.shared.windows.first?.rootViewController?.view.snapshot {
              //          UIImageWriteToSavedPhotosAlbum(capture, nil, nil, nil)
                        cameraManager.uploadPhoto(image)
                    
                    
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

extension UIView {
    // UIViewのスクリーンショットを取得するプロパティ
    var snapshot: UIImage? {
        UIGraphicsBeginImageContextWithOptions(bounds.size, false, UIScreen.main.scale)
        defer { UIGraphicsEndImageContext() }
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        layer.render(in: context)
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
