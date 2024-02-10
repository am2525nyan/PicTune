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
                
                previewLayer.frame = CGRect(x: (UIScreen.main.bounds.width - 284) / 2, y: (UIScreen.main.bounds.height - 390) / 2 - 55, width: 287, height: 390)
                view.layer.addSublayer(previewLayer)
            }
        }
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}
