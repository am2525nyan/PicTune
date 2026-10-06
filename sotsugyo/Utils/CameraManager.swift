import AVFoundation
import Photos
import Vision
import FirebaseAuth
import FirebaseStorage
import SwiftUI
import FirebaseFirestore
import Combine
import CoreImage
import CoreImage.CIFilterBuiltins
import PhotosUI
import Photos

class CameraManager: NSObject, AVCapturePhotoCaptureDelegate, ObservableObject {
    let captureSession = AVCaptureSession()
    var previewLayer: AVCaptureVideoPreviewLayer?
    var photoOutput = AVCapturePhotoOutput()
    @Published var capturedImage: UIImage?
    @Environment(\.presentationMode) var presentation
    @State private var isPresentingMain = false
    @State private var isPresentingCamera = true
    @Published var isImageUploadCompleted = false
    @Published var isPresentingSearch = false
    var saveArray: Array! = [NSData]()
    let savedata = UserDefaults.standard
    @Published var newImage: UIImage?
    @Published var documentId = "default_value"
    @Published var friendUid = ""
    private var compressedData: Data?
    var livePhotoCompanionMovieURL: URL?
    var liveurl = ""
    //カメラの準備
    func setupCaptureSession() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = AVCaptureSession.Preset.photo
        
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .front)
        
        guard let camera = deviceDiscoverySession.devices.first else {
            print("Front camera not found.")
            return
        }
        
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
        if self.photoOutput.isLivePhotoCaptureSupported {
          self.photoOutput.isLivePhotoCaptureEnabled = true
        }
        captureSession.commitConfiguration()
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        
        previewLayer?.videoGravity = .resizeAspectFill
        print("セットアップ終わり")
        
        startSession()
    }
    
    
    //スタート！
    func startSession() {
        
        DispatchQueue.global().async {
            self.captureSession.startRunning()
            print("いいよ")
            
            
        }
    }
    //終わり
    func stopSession() {
        if captureSession.isRunning {
            DispatchQueue.global().async {
                self.captureSession.stopRunning()
                print("終わり")
            }
        }
    }
    
    
    
    
    func captureImage() {
        
      
       var settingsForMonitoring = AVCapturePhotoSettings()
        let previewWidth = UIScreen.main.bounds.width * 0.864
        let previewHeight = UIScreen.main.bounds.height * 0.536
        
        settingsForMonitoring.previewPhotoFormat = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: previewWidth,
            kCVPixelBufferHeightKey as String: previewHeight
        ]
        
       
        settingsForMonitoring.embeddedThumbnailPhotoFormat = [AVVideoCodecKey : AVVideoCodecType.jpeg]
        settingsForMonitoring.isHighResolutionPhotoEnabled = false

        if self.photoOutput.isLivePhotoCaptureSupported {
            // 動画の保存先URLの作成
            let livePhotoMovieFileName = NSUUID().uuidString
            let livePhotoMovieFilePath = (NSTemporaryDirectory() as NSString).appendingPathComponent((livePhotoMovieFileName as NSString).appendingPathExtension("mov")!)
            settingsForMonitoring.livePhotoMovieFileURL = URL(fileURLWithPath: livePhotoMovieFilePath)
        }
        AudioServicesPlaySystemSound(1108)
        self.photoOutput.capturePhoto(with: settingsForMonitoring, delegate: self)
     
        
    }
    func photoOutput(_ output: AVCapturePhotoOutput, willBeginCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
       print("撮影開始")
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
        
        let previewSize = CGSize(width: UIScreen.main.bounds.width * 0.864, height: UIScreen.main.bounds.height * 0.536)
        let metaRect = CGRect(x: 0, y: 0, width: previewSize.width, height: previewSize.height)
        let metaRectConverted = previewLayer?.metadataOutputRectConverted(fromLayerRect: metaRect) ?? CGRect.zero
        let cropRect: CGRect = CGRect(x: metaRectConverted.origin.x * originalSize.width,
                                      y: metaRectConverted.origin.y * originalSize.height,
                                      width: metaRectConverted.size.width * originalSize.width,
                                      height: metaRectConverted.size.height * originalSize.height).integral
        
        guard let cgImage = image.cgImage?.cropping(to: cropRect) else { return }
        let croppedImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
        
        
        
        
        image = croppedImage.rotateLeft90Degrees()
        
        if let filteredImage = applySepiaFilter(to: image) {
            DispatchQueue.main.async {
                self.newImage = filteredImage
                self.isImageUploadCompleted = true
            }
        }
    
    guard let photoData = photo.fileDataRepresentation() else {
        print("No photo data to write.")
        return
    }
    self.compressedData = photoData // 保持
    }
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishRecordingLivePhotoMovieForEventualFileAt outputFileURL: URL, resolvedSettings: AVCaptureResolvedPhotoSettings) {
       print("撮影終わり")
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingLivePhotoToMovieFileAt outputFileURL: URL, duration: CMTime, photoDisplayTime: CMTime, resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
      if error != nil {
        print("Error processing Live Photo companion movie: \(String(describing: error))")
        return
      }
      self.livePhotoCompanionMovieURL = outputFileURL
    }
    
    
    
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
                     error: Error?) {
        
        guard error == nil else {

            print("Error capture photo: \(error!)")
            return
        }
        
        guard let compressedData = self.compressedData else {
         
            print("The expected photo data isn't available.")
            return
        }
        
  
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized else { return }
            PHPhotoLibrary.shared().performChanges {
                let creationRequest = PHAssetCreationRequest.forAsset()
                creationRequest.addResource(with: .photo, data: compressedData, options: nil)
                if let livePhotoCompanionMovieURL = self.livePhotoCompanionMovieURL {
                    let livePhotoCompanionMovieFileOptions = PHAssetResourceCreationOptions()
                    livePhotoCompanionMovieFileOptions.shouldMoveFile = true
                    creationRequest.addResource(with: .pairedVideo,
                                                fileURL: livePhotoCompanionMovieURL,
                                                options: livePhotoCompanionMovieFileOptions)
                }
            } completionHandler: { success, error in
              
                
                if let _ = error {
                    print("Error save photo: \(error!)")
                }
            }
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
    
    
    @MainActor
    func uploadPhoto(_ image: UIImage, friendUid: String, track: Track? = nil) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "PhotoSave", code: 1, userInfo: [NSLocalizedDescriptionKey: "ログイン状態を確認してください。"])
        }
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            throw NSError(domain: "PhotoSave", code: 2, userInfo: [NSLocalizedDescriptionKey: "写真を作成できませんでした。"])
        }

        let imageName = "\(UUID().uuidString).jpg"
        let imageReference = Storage.storage().reference().child("images/\(imageName)")
        _ = try await imageReference.putDataAsync(imageData)

        let db = Firestore.firestore()
        let folder = db.collection("users").document(uid).collection("folders").document("all")
        let photo = folder.collection("photos").document()
        let record = PhotoRecord(id: photo.documentID, fileName: imageName, date: nil,
                                 music: track.map { FirebaseMusic(photoID: photo.documentID, track: $0) },
                                 livePhotoFileName: liveurl)
        let data = record.firestoreData(date: FieldValue.serverTimestamp())
        let batch = db.batch()
        batch.setData(data, forDocument: photo)
        batch.setData(["title": "all", "date": FieldValue.serverTimestamp()], forDocument: folder, merge: true)
        if !friendUid.isEmpty && friendUid != uid {
            let friendPhoto = db.collection("users").document(friendUid).collection("folders").document("all").collection("photos").document(photo.documentID)
            batch.setData(data, forDocument: friendPhoto)
        }
        do {
            try await batch.commit()
            documentId = photo.documentID
        } catch {
            try? await imageReference.delete()
            throw error
        }
    }

    func resizeImage(_ image: UIImage, newSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { (context) in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    func uploadLivePhotoToFirebase() {
         guard let livePhotoData = self.compressedData else {
             print("No Live Photo data to upload.")
             return
         }

         let livePhotoFileName = UUID().uuidString
         let livePhotoFilePath = (NSTemporaryDirectory() as NSString).appendingPathComponent((livePhotoFileName as NSString).appendingPathExtension("mov")!)

         do {
             try livePhotoData.write(to: URL(fileURLWithPath: livePhotoFilePath), options: [.atomic])
         } catch {
             print("Failed to write Live Photo data to file: \(error.localizedDescription)")
             return
         }

         let storageRef = Storage.storage().reference().child("livephotos/\(livePhotoFileName).mov")

         storageRef.putFile(from: URL(fileURLWithPath: livePhotoFilePath), metadata: nil) { (metadata, error) in
             if let error = error {
                 print("Error uploading Live Photo to Firebase Storage: \(error.localizedDescription)")
             } else {
                 print("Live Photo uploaded successfully. Metadata: \(String(describing: metadata))")

                 // Firebase StorageからダウンロードするためのURLを取得
                 storageRef.downloadURL { (url, error) in
                     if let downloadURL = url {
                         self.liveurl = downloadURL.absoluteString
                         print("Live Photo download URL: \(self.liveurl)")
                     } else if let error = error {
                         print("Error getting Live Photo download URL: \(error.localizedDescription)")
                     }
                 }
             }
         }
     }

}
extension UIImage {
    func rotateLeft90Degrees() -> UIImage {
        let radians =  CGFloat.pi/1500
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

