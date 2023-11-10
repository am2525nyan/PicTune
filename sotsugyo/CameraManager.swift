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
    
    init(isPresentingCamera: Binding<Bool>) {
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
        sepiaFilter.intensity = 0.8
        
        if let outputImage = sepiaFilter.outputImage, let cgimg = context.createCGImage(outputImage, from: outputImage.extent) {
            uploadPhoto(UIImage(cgImage: cgimg))
            return UIImage(cgImage: cgimg)
        }
        return nil
    }
    
    
    //写真をfirestorageに保存
    func uploadPhoto(_ image: UIImage) {
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            return
        }
        
        let imageName = UUID().uuidString
        let imageReference = Storage.storage().reference().child("images/\(imageName).jpg")
        let url = ("\(imageName).jpg")
        uploadLink(url: url)
        imageReference.putData(imageData, metadata: nil) { metadata, error in
            guard metadata != nil else {
                return
            }
            
            
            imageReference.downloadURL { url, error in
                guard let downloadURL = url else {
                    
                    return
                }
                
                
            }
        }
    }
    
    
    //写真をfirestorageのurlをfirestoreに保存 あとで非同期にする
    func uploadLink(url: String){
        let db = Firestore.firestore()
        let uid = Auth.auth().currentUser?.uid
        
        var urlArray = [String]()
        
        db.collection("users").document(uid ?? "").collection("photo").document("list").getDocument(){ (document, error) in
            
            if let document = document, document.exists {
                let data = document.data()
                let urlList = data?["urlList"] as! Array<Any>
                for string in urlList {
                    urlArray.append(string as! String)
                }
            }
            
            urlArray.append(url)
            
            db.collection("users").document(uid ?? "").collection("photo").document("list").delete() { err in
                if let err = err {
                    print("Error removing document: \(err)")
                } else {
                    print("Document successfully removed!")
                }
            }
            db.collection("users").document(uid ?? "").collection("photo").document("list").setData([
                "urlList": urlArray
                
            ]) { err in
                if let err = err {
                    print("Error writing document: \(err)")
                } else {
                    
                    self.isImageUploadCompleted = true
                    print("保存しました！")
                  
                }
            }
            
            
        }
    }
    func idou(){
                
                MainContentView()
                    .edgesIgnoringSafeArea(.all)
                
            
    }
}
