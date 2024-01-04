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
                let previewY = CGFloat(108)
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









/*
 動きそうで動かないやつ ファイルは使ってない

class Mask: SCNNode, VirtualFaceContent {

    init(geometry: ARSCNFaceGeometry) {
        let material = geometry.firstMaterial //初期化
        material?.diffuse.contents = UIColor.gray //マスクの色
        material?.lightingModel = .physicallyBased //オブジェクトの照明のモデル

        super.init()
        self.geometry = geometry
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("\(#function) has not been implemented")
    }

    //ARアンカーがアップデートされた時に呼ぶ
    func update(withFaceAnchor anchor: ARFaceAnchor) {
        guard let faceGeometry = geometry as? ARSCNFaceGeometry else { return }
        faceGeometry.update(from: anchor.geometry)
    }
}

protocol VirtualFaceContent {
    func update(withFaceAnchor: ARFaceAnchor)
}

typealias VirtualFaceNode = VirtualFaceContent & SCNNode
class VirtualContentUpdater: NSObject, ARSCNViewDelegate {

    //表示 or 更新用
    var virtualFaceNode: VirtualFaceNode? {
        didSet {
            setupFaceNodeContent()
        }
    }
    //セッションを再起動する必要がないように保持用
    private var faceNode: SCNNode?

    private let serialQueue = DispatchQueue(label: "com.example.serial-queue")

    //マスクのセットアップ
    private func setupFaceNodeContent() {
        guard let faceNode = faceNode else { return }

        //全ての子ノードを消去
        for child in faceNode.childNodes {
            child.removeFromParentNode()
        }
        //新しいノードを追加
        if let content = virtualFaceNode {
            faceNode.addChildNode(content)
        }
    }

    //MARK: - ARSCNViewDelegate
    //新しいARアンカーが設置された時に呼び出される
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        faceNode = node
        serialQueue.async {
            self.setupFaceNodeContent()
        }
    }

    //ARアンカーが更新された時に呼び出される
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        virtualFaceNode?.update(withFaceAnchor: faceAnchor) //マスクをアップデートする
    }
}

 
 
struct ARFaceTrackingViewWrapper: UIViewControllerRepresentable {
    class Coordinator: NSObject, ARSessionDelegate {
        var parent: ARFaceTrackingViewWrapper
        var coordinatorContentUpdater = VirtualContentUpdater()
        var contentUpdater = VirtualContentUpdater()
        init(parent: ARFaceTrackingViewWrapper) {
            self.parent = parent
        }
        
        func makeUIViewController(context: Context) -> ARViewController {
                  let arViewController = ARViewController()
                  arViewController.contentUpdater = coordinatorContentUpdater
                  return arViewController
              }
        
        func session(_ session: ARSession, didFailWithError error: Error) {
            guard error is ARError else { return }
            print("SESSION ERROR")
        }

        func sessionWasInterrupted(_ session: ARSession) {
            print("SESSION INTERRUPTED")
        }

        func sessionInterruptionEnded(_ session: ARSession) {
            DispatchQueue.main.async {
                self.parent.arViewController.startSession()
            }
        }
    }

    var contentUpdater = VirtualContentUpdater()
    var arViewController = ARViewController()

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> ARViewController {
        arViewController.contentUpdater = contentUpdater
        return arViewController
    }

    func updateUIViewController(_ uiViewController: ARViewController, context: Context) {
        // Update logic (if needed)
    }
}

class ARViewController: UIViewController, ARSessionDelegate {
    var sceneView = ARSCNView()
    var contentUpdater: VirtualContentUpdater?

    override func viewDidLoad() {
        super.viewDidLoad()
        sceneView.delegate = contentUpdater
        sceneView.session.delegate = self
        sceneView.automaticallyUpdatesLighting = true

        if let virtualFaceNode = createFaceNode() {
            contentUpdater?.virtualFaceNode = virtualFaceNode
        }

        view.addSubview(sceneView)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIApplication.shared.isIdleTimerDisabled = true
        startSession()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }

    func createFaceNode() -> VirtualFaceNode? {
        guard let device = sceneView.device, let geometry = ARSCNFaceGeometry(device: device) else {
            return nil
        }

        return Mask(geometry: geometry)
    }

    func startSession() {
        print("STARTING A NEW SESSION")
        guard ARFaceTrackingConfiguration.isSupported else { return }
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
}

 なんが画面全部scnファイルの縁取り？になる中黒い
import SwiftUI
import ARKit
import SceneKit

struct ARFaceTrackingView: UIViewControllerRepresentable {
    class Coordinator: NSObject, ARSCNViewDelegate {
        var parent: ARFaceTrackingView

        init(parent: ARFaceTrackingView) {
            self.parent = parent
        }

        func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
            guard let faceAnchor = anchor as? ARFaceAnchor else { return }
            DispatchQueue.main.async {
                // Ensure faceGeometry is not nil before updating
                if let faceGeometry = self.parent.faceGeometry {
                    print("faceGeometry is not nil")
                    faceGeometry.update(from: faceAnchor.geometry)
                    node.addChildNode(self.parent.createFaceNode())
                } else {
                    print("faceGeometry is nil")
                }
            }

        }

        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            guard let faceAnchor = anchor as? ARFaceAnchor else { return }

            // Ensure faceGeometry is not nil before updating
            if let faceGeometry = parent.faceGeometry {
                faceGeometry.update(from: faceAnchor.geometry)
            }
        }
        
    }

    @Binding var faceGeometry: ARSCNFaceGeometry?
    

    init(faceGeometry: Binding<ARSCNFaceGeometry?>) {
        _faceGeometry = faceGeometry
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        let sceneView = ARSCNView()
        sceneView.delegate = context.coordinator
        sceneView.automaticallyUpdatesLighting = true
        sceneView.scene = SCNScene()
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        viewController.view = sceneView

        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Update logic (if needed)
    }
    func createFaceNode() -> SCNNode {
        if let faceGeometry = faceGeometry {
            let faceNode = SCNNode(geometry: faceGeometry)
            // Customize faceNode if needed
            return faceNode
        } else {
            // Handle the case where faceGeometry is nil
            return SCNNode()
        }
    }

}


*/
