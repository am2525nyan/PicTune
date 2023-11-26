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
    @State private var isPresentingCamera = true
    @Published var isImageUploadCompleted = false
    var saveArray: Array! = [NSData]()
    let savedata = UserDefaults.standard
    @Published var newImage: UIImage?
   
    
    
    override init() {
        
     
        super.init()
     
       
    }
    //カメラの準備
    func setupCaptureSession() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = AVCaptureSession.Preset.photo
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
        captureSession.startRunning()
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        
              previewLayer?.videoGravity = .resizeAspectFill
        
      
    }
    
  
    //スタート！
    func startSession() {
       
        if !captureSession.isRunning {
          
                self.captureSession.startRunning()
            
          
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
       
           let previewWidth = UIScreen.main.bounds.width * 0.864
           let previewHeight = UIScreen.main.bounds.height * 0.536
        
        settings.previewPhotoFormat = [
               kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
               kCVPixelBufferWidthKey as String: previewWidth,
               kCVPixelBufferHeightKey as String: previewHeight 
           ]


        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              var image = UIImage(data: imageData) else {
            print(error as Any)
            return }
     
        var originalSize: CGSize
           if image.imageOrientation == .left || image.imageOrientation == .right {
               originalSize = CGSize(width: image.size.height, height: image.size.width)
           } else {
               originalSize = image.size
           }

           // プレビューのサイズを利用してmetaRectを計算
           let previewSize = CGSize(width: UIScreen.main.bounds.width * 0.864, height: UIScreen.main.bounds.height * 0.536)
           let metaRect = CGRect(x: 0, y: 0, width: previewSize.width, height: previewSize.height)

           // previewLayerのrectを切り抜きたいviewの座標系に変換
           let metaRectConverted = previewLayer?.metadataOutputRectConverted(fromLayerRect: metaRect) ?? CGRect.zero
           // 切り抜く範囲を計算
           let cropRect: CGRect = CGRect(x: metaRectConverted.origin.x * originalSize.width,
                                         y: metaRectConverted.origin.y * originalSize.height,
                                         width: metaRectConverted.size.width * originalSize.width,
                                         height: metaRectConverted.size.height * originalSize.height).integral

        // 画像を切り取る
        guard let cgImage = image.cgImage?.cropping(to: cropRect) else { return }
        let croppedImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)

        
        
        
        image = croppedImage.rotateLeft90Degrees()

        if let filteredImage = applySepiaFilter(to: image) {
            self.isImageUploadCompleted = true
            self.newImage = filteredImage
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
    
    
    //写真をfirestorageのurlをfirestoreに保存
    func uploadLink(url: String) async throws{
        let db = Firestore.firestore()
        let uid = Auth.auth().currentUser?.uid
        
      
        
        DispatchQueue.main.sync{
            
            db.collection("users").document(uid ?? "").collection("photo").addDocument(data: [
                "url": url,
                "date": FieldValue.serverTimestamp()
            ])
            print("保存しました！")
          
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
           
            self.isImageUploadCompleted = true
            print("戻りました！")
        }
    }
    
    func resizeImage(_ image: UIImage, newSize: CGSize) -> UIImage {
           let renderer = UIGraphicsImageRenderer(size: newSize)
           return renderer.image { (context) in
               image.draw(in: CGRect(origin: .zero, size: newSize))
           }
       }
    
}
extension UIImage {
    func rotateLeft90Degrees() -> UIImage {
        let radians =  CGFloat.pi/360
        let rotatedSize = CGRect(origin: .zero, size: size)
            .applying(CGAffineTransform(rotationAngle: CGFloat(radians)))
            .integral.size

        UIGraphicsBeginImageContext(rotatedSize)
        if let context = UIGraphicsGetCurrentContext() {
            context.translateBy(x: rotatedSize.width / 2, y: rotatedSize.height / 2)
            context.rotate(by: radians)
            draw(in: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
            let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return rotatedImage ?? self
        }
        return self
    }
}


