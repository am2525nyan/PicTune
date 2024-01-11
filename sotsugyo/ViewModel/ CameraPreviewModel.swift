import SwiftUI
import ARKit
import SceneKit
import UIKit

struct CameraPreview: UIViewRepresentable {
    let cameraManager: CameraManager
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            if let previewLayer = cameraManager.previewLayer {
                previewLayer.videoGravity = .resizeAspectFill
                
                let previewX = CGFloat(27)
                let previewY = CGFloat(73)
                let previewWidth = UIScreen.main.bounds.width * 0.864
                let previewHeight = UIScreen.main.bounds.height * 0.536
                previewLayer.frame = CGRect(x: previewX, y: previewY, width: previewWidth, height: previewHeight)
                
                view.layer.addSublayer(previewLayer)
            }
        }
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}
