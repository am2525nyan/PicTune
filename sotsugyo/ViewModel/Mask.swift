//
//  Mask.swift
//  sotsugyo
//
//  Created by saki on 2024/01/03.
//
import SwiftUI
import ARKit
import SceneKit

class Mask: SCNNode, VirtualFaceContent {

    init(geometry: ARSCNFaceGeometry) {
        let material = geometry.firstMaterial // 初期化
        material?.diffuse.contents = UIColor.gray // マスクの色
        material?.lightingModel = .physicallyBased // オブジェクトの照明のモデル

        super.init()
        self.geometry = geometry
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("\(#function) has not been implemented")
    }

    // ARアンカーがアップデートされた時に呼ぶ
    func update(withFaceAnchor anchor: ARFaceAnchor) {
        guard let faceGeometry = geometry as? ARSCNFaceGeometry else { return }
        faceGeometry.update(from: anchor.geometry)
    }
}

protocol VirtualFaceContent {
    func update(withFaceAnchor: ARFaceAnchor)
}

typealias VirtualFaceNode = VirtualFaceContent & SCNNode



struct ARFaceView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ARFaceViewController {
        let arFaceViewController = ARFaceViewController()
        return arFaceViewController
    }

    func updateUIViewController(_ uiViewController: ARFaceViewController, context: Context) {}
}


class ARFaceViewController: UIViewController, ARSessionDelegate {
    private var sceneView = ARSCNView()
    private var contentUpdater = VirtualContentUpdater()

    override func viewDidLoad() {
        super.viewDidLoad()

        sceneView.delegate = contentUpdater
        sceneView.session.delegate = self
        sceneView.automaticallyUpdatesLighting = true

        contentUpdater.virtualFaceNode = createFaceNode()

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

    public func createFaceNode() -> VirtualFaceNode? {
        guard let device = sceneView.device,
              let geometry = ARSCNFaceGeometry(device: device) else {
            return nil
        }

        return Mask(geometry: geometry)
    }
    //MARK: - ARSessionDelegat
    //エラーの時
    func session(_ session: ARSession, didFailWithError error: Error) {
        guard error is ARError else { return }
        print("SESSION ERROR")
    }
    //中断した時
    func sessionWasInterrupted(_ session: ARSession) {
        print("SESSION INTERRUPTED")
    }
    //中断再開した時
    func sessionInterruptionEnded(_ session: ARSession) {
        DispatchQueue.main.async {
            self.startSession() //セッション再開
        }
    }

    func startSession() {
        guard ARFaceTrackingConfiguration.isSupported else { return }
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

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

}


