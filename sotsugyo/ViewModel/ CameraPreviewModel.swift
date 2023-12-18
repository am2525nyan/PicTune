//
//   CameraPreview.swift
//  sotsugyo
//
//  Created by saki on 2023/11/06.
//
import SwiftUI
import AVFoundation
import ARKit

struct CameraPreview: UIViewRepresentable {
    let cameraManager: CameraManager

    func makeUIView(context: Context) -> UIView {
        let view = UIView()

        DispatchQueue.main.async {
            if let previewLayer = cameraManager.previewLayer {
                previewLayer.videoGravity = .resizeAspectFill

                let previewX = CGFloat(27)
                let previewY = CGFloat(131)
                let previewWidth = UIScreen.main.bounds.width * 0.864
                let previewHeight = UIScreen.main.bounds.height * 0.536
                previewLayer.frame = CGRect(x: previewX, y: previewY, width: previewWidth, height: previewHeight)

                view.layer.addSublayer(previewLayer)

                // Add ARFaceTracking
                let arConfiguration = ARFaceTrackingConfiguration()
                let sceneView = ARSCNView(frame: CGRect(x: previewX, y: previewY, width: previewWidth, height: previewHeight))
                sceneView.session.run(arConfiguration)
                sceneView.delegate = context.coordinator
                view.addSubview(sceneView)
            }
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, ARSCNViewDelegate {
        var parent: CameraPreview

        init(_ parent: CameraPreview) {
            self.parent = parent
        }

        func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
            // Create and configure a node for the anchor
            let faceNode = SCNNode()

            // Add your AR content here, e.g., a color mask
            let colorMask = SCNBox(width: 0.1, height: 0.1, length: 0.1, chamferRadius: 0)
            colorMask.firstMaterial?.diffuse.contents = UIColor.red
            faceNode.addChildNode(SCNNode(geometry: colorMask))

            return faceNode
        }
    }
}
