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
    @State private var isPresentingImagePicker = false
    @State private var screenshotImage: UIImage?
    var body: some View {
        VStack {
            if let image = images {
                
                Button("保存") {
                    takeScreenshot()
                    //       if let capture = UIApplication.shared.windows.first?.rootViewController?.view.snapshot {
                    
                    UIImageWriteToSavedPhotosAlbum(screenshotImage ?? image, nil, nil, nil)
                    cameraManager.uploadPhoto(screenshotImage ?? image)
                    
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
    func takeScreenshot() {
        if let window = UIApplication.shared.windows.first {
            let screenshotRect = CGRect(x: 4, y: 158, width: UIScreen.main.bounds.width * 0.988, height: UIScreen.main.bounds.height * 0.726)
            
            UIGraphicsBeginImageContextWithOptions(screenshotRect.size, false, UIScreen.main.scale)
            window.drawHierarchy(in: CGRect(origin: CGPoint(x: -screenshotRect.origin.x, y: -screenshotRect.origin.y), size: window.bounds.size), afterScreenUpdates: true)
            let screenshotImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            self.screenshotImage = screenshotImage
            
            isPresentingImagePicker = true
        }
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
