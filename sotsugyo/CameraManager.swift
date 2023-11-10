import AVFoundation
import SwiftUI

class CameraManager: NSObject, AVCapturePhotoCaptureDelegate {
    let captureSession = AVCaptureSession()
    var previewLayer: AVCaptureVideoPreviewLayer?
    var photoOutput = AVCapturePhotoOutput()
    
    override init() {
        super.init()
        setupCaptureSession()
    }
    
    private func setupCaptureSession() {
        // カメラデバイスの設定
        guard let camera = AVCaptureDevice.default(for: .video) else { return }
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
        } catch {
            print(error.localizedDescription)
        }
        
        // カメラセッションの設定
        captureSession.beginConfiguration()
        // セッションの設定...
        captureSession.commitConfiguration()
        
        // プレビューレイヤーの設定
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = .resizeAspectFill // ここで縦横比を調整
        // プレビューレイヤーをビュー階層に追加...
    }
    
    func startSession() {
        if !captureSession.isRunning {
            captureSession.startRunning()
        }
    }
    
    func stopSession() {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
    func captureImage() {
            let settings = AVCapturePhotoSettings()
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
}
