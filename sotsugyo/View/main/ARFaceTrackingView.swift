//
//  ARFaceTrackingView.swift
//  sotsugyo
//
//  Created by saki on 2023/12/18.
//
import SwiftUI
import SceneKit
import ARKit

struct ARFaceTrackingView: UIViewRepresentable {
    @Binding var laughingmanNode: SCNReferenceNode?
    

    func makeUIView(context: Context) -> ARSCNView {
        
        let arView = ARSCNView()
    
        arView.delegate = context.coordinator
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
      


        return arView
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
       

        uiView.scene.rootNode.enumerateChildNodes { (node, _) in
            node.removeFromParentNode()
        }

        if uiView.session.currentFrame?.anchors.isEmpty == true, let content = laughingmanNode {
            // 顔面にノードを追加
            uiView.scene.rootNode.addChildNode(content)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, ARSCNViewDelegate {
        var parent: ARFaceTrackingView
        
        init(_ parent: ARFaceTrackingView) {
            self.parent = parent
        }
        
        func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
            guard anchor is ARFaceAnchor else { return }
            
            if node.childNodes.isEmpty, let content = parent.laughingmanNode {
                content.scale = SCNVector3(1.5, 1.5, 1.5)

                // ノードを読み込み
                content.load()
                
                // 顔面にノードを追加
                node.addChildNode(content)
            }
        }
    }
}
 





