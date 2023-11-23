//
//   CameraPreview.swift
//  sotsugyo
//
//  Created by saki on 2023/11/06.
//

import SwiftUI

struct CameraPreview: UIViewRepresentable {
    let cameraManager: CameraManager
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
       
        if let previewLayer = cameraManager.previewLayer {
            previewLayer.videoGravity = .resizeAspectFill
          
            let previewX = CGFloat(27)
            let previewY = CGFloat(131)
            let previewWidth = UIScreen.main.bounds.width * 0.864
            let previewHeight = UIScreen.main.bounds.height * 0.536
            previewLayer.frame = CGRect(x: previewX, y: previewY, width: previewWidth, height: previewHeight)

         
            view.layer.addSublayer(previewLayer)
        }
        
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
