import AVFoundation
import FirebaseAuth
import FirebaseStorage
import SwiftUI
import FirebaseFirestore
import Combine
import CoreImage
import CoreImage.CIFilterBuiltins

class CameraManager: NSObject, AVCapturePhotoCaptureDelegate, ObservableObject {
    let captureSession = AVCaptureSession()
    var previewLayer: AVCaptureVideoPreviewLayer?
    var photoOutput = AVCapturePhotoOutput()
    @Published var capturedImage: UIImage?
    @Environment(\.presentationMode) var presentation
    @State private var isPresentingMain = false
    @Binding var isPresentingCamera: Bool
    @Published var isImageUploadCompleted = false
    var saveArray: Array! = [NSData]()
    let savedata = UserDefaults.standard
    @Binding var documentId: String?
    
    
    init(isPresentingCamera: Binding<Bool>, documentId: Binding<String?>) {
        _documentId = documentId
        _isPresentingCamera = isPresentingCamera
        super.init()
        setupCaptureSession()
        
    }
    //カメラの準備
    func setupCaptureSession() {
        captureSession.beginConfiguration()
        guard let camera = AVCaptureDevice.default(for: .video) else { return }
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
            if captureSession.canAddOutput(photoOutput) {
                captureSession.addOutput(photoOutput)
            }
        } catch {
            print(error.localizedDescription)
            return
        }
        
        captureSession.commitConfiguration()
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = .resizeAspectFill
        
    }
    //スタート！
    func startSession() {
        if !captureSession.isRunning {
            DispatchQueue.global().async {
                self.captureSession.startRunning()
            }
        }
    }
    //終わり
    func stopSession() {
        if captureSession.isRunning {
            DispatchQueue.global().async {
                self.captureSession.stopRunning()
            }
        }
    }
    
    
    
    
    func captureImage() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else { return }
        
        if let filteredImage = applySepiaFilter(to: image) {
            uploadPhoto(filteredImage)
            
        }
    }
    
    func applySepiaFilter(to inputImage: UIImage) -> UIImage? {
        let context = CIContext()
        let sepiaFilter = CIFilter.sepiaTone()
        guard let ciImage = CIImage(image: inputImage) else { return nil }
        
        sepiaFilter.inputImage = ciImage
        sepiaFilter.intensity = 0.2
        
        if let outputImage = sepiaFilter.outputImage, let cgimg = context.createCGImage(outputImage, from: outputImage.extent) {
           
            return UIImage(cgImage: cgimg)
        }
        return nil
    }
    
    
    //写真をfirestorageに保存
    func uploadPhoto(_ image: UIImage) {
        
        guard let imageData = image.jpegData(compressionQuality: 0.2) else {
            return
        }
        
        let imageName = UUID().uuidString
        let imageReference = Storage.storage().reference().child("images/\(imageName).jpg")
        let url = ("\(imageName).jpg")
        
        
        imageReference.putData(imageData, metadata: nil) { metadata, error in
          
                Task{
                    do{
                        try await self.uploadLink(url: url)
                       
                       
                    }
                }
              
        
                return
                
        }
    }
    
    
    //写真をfirestorageのurlをfirestoreに保存 あとで非同期にする
    func uploadLink(url: String) async throws{
        let db = Firestore.firestore()
        let uid = Auth.auth().currentUser?.uid
        
        var urlArray = [String]()
        
        DispatchQueue.main.sync{
            
            let ref = db.collection("users").document(uid ?? "").collection("photo").addDocument(data: [
                "url": url,
                "date": FieldValue.serverTimestamp()
            ])
            documentId?.append(ref.documentID)
            print("保存しました！")
          
        }
        self.isImageUploadCompleted = true
        print("戻りました！")
      
    }
    
}
