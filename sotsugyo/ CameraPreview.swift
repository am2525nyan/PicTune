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
            let view = UIView(frame: UIScreen.main.bounds)
            
            // セッションが開始された後にプレビューレイヤーが設定されるようにします。
            if let previewLayer = cameraManager.previewLayer {
                previewLayer.frame = view.bounds
                view.layer.addSublayer(previewLayer)
            }

            return view
        }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}
