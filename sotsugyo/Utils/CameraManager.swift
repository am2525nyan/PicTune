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
    private let sessionQueue = DispatchQueue(label: "PicTune.CameraSession")
    private var isSessionConfigured = false
    private var isCapturing = false
    private var wantsRunning = false
    private var previewGeneration = UUID()
    private var capturePreviewGeneration = UUID()

    // Session configuration, capture and start/stop must use the same serial queue.
    @MainActor
    func setupCaptureSession() {
        previewGeneration = UUID()
        newImage = nil
        isImageUploadCompleted = false
        if previewLayer == nil {
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer?.videoGravity = .resizeAspectFill
        }
        sessionQueue.async {
            self.wantsRunning = true
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                self.configureAndStartSession()
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    self.sessionQueue.async {
                        if granted && self.wantsRunning { self.configureAndStartSession() }
                    }
                }
            default:
                break
            }
        }
    }

    private func configureAndStartSession() {
        guard wantsRunning else { return }
        if !isSessionConfigured {
            captureSession.beginConfiguration()
            // Always close configuration, including devices without a camera.
            defer { captureSession.commitConfiguration() }
            captureSession.sessionPreset = .photo
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
                return
            }
            do {
                let input = try AVCaptureDeviceInput(device: camera)
                guard captureSession.canAddInput(input), captureSession.canAddOutput(photoOutput) else { return }
                captureSession.addInput(input)
                captureSession.addOutput(photoOutput)
                if photoOutput.isLivePhotoCaptureSupported {
                    photoOutput.isLivePhotoCaptureEnabled = true
                }
                isSessionConfigured = true
            } catch {
                print(error.localizedDescription)
                return
            }
        }
        guard !captureSession.isRunning else { return }
        captureSession.startRunning()
    }

    func startSession() {
        sessionQueue.async {
            self.wantsRunning = true
            self.configureAndStartSession()
        }
    }

    @MainActor
    func stopSession() {
        previewGeneration = UUID()
        sessionQueue.async {
            self.wantsRunning = false
            if self.captureSession.isRunning { self.captureSession.stopRunning() }
        }
    }

    @MainActor
    func captureImage() {
        let generation = previewGeneration
        sessionQueue.async {
            guard self.captureSession.isRunning, !self.isCapturing,
                  let connection = self.photoOutput.connection(with: .video), connection.isActive else { return }
            self.isCapturing = true
            self.capturePreviewGeneration = generation
            self.compressedData = nil
            self.livePhotoCompanionMovieURL = nil
            self.liveurl = ""
            let settings = AVCapturePhotoSettings()
            if self.photoOutput.isLivePhotoCaptureEnabled {
                settings.livePhotoMovieFileURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
            }
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
    func photoOutput(_ output: AVCapturePhotoOutput, willBeginCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
       print("撮影開始")
    }
    
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print(error as Any)
            return
        }
        compressedData = imageData
        let generation = capturePreviewGeneration
        DispatchQueue.main.async {
            guard generation == self.previewGeneration else { return }
            guard let previewLayer = self.previewLayer, !previewLayer.bounds.isEmpty else { return }
            let rect = previewLayer.metadataOutputRectConverted(fromLayerRect: previewLayer.bounds)
            guard let croppedImage = Self.croppedPhoto(image, normalizedRect: rect),
                  let filteredImage = self.applySepiaFilter(to: croppedImage) else { return }
            self.newImage = filteredImage
            self.isImageUploadCompleted = true
        }
    }

    static func croppedPhoto(_ image: UIImage, normalizedRect: CGRect) -> UIImage? {
        guard let source = image.cgImage else { return nil }
        let bounds = CGRect(x: 0, y: 0, width: source.width, height: source.height)
        let crop = CGRect(x: normalizedRect.minX * bounds.width,
                          y: normalizedRect.minY * bounds.height,
                          width: normalizedRect.width * bounds.width,
                          height: normalizedRect.height * bounds.height).integral.intersection(bounds)
        guard !crop.isNull, !crop.isEmpty, let result = source.cropping(to: crop) else { return nil }
        let orientedImage = UIImage(cgImage: result, scale: image.scale, orientation: image.imageOrientation)
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        return UIGraphicsImageRenderer(size: orientedImage.size, format: format).image { _ in
            orientedImage.draw(in: CGRect(origin: .zero, size: orientedImage.size))
        }
    }
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishRecordingLivePhotoMovieForEventualFileAt outputFileURL: URL, resolvedSettings: AVCaptureResolvedPhotoSettings) {
       print("撮影終わり")
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingLivePhotoToMovieFileAt outputFileURL: URL, duration: CMTime, photoDisplayTime: CMTime, resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
      if error != nil {
        try? FileManager.default.removeItem(at: outputFileURL)
        print("Error processing Live Photo companion movie: \(String(describing: error))")
        return
      }
      self.livePhotoCompanionMovieURL = outputFileURL
    }
    
    
    
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
                     error: Error?) {
        
        let movieURL = livePhotoCompanionMovieURL
        let photoData = compressedData
        sessionQueue.async { self.isCapturing = false }
        guard error == nil else {
            if let movieURL { try? FileManager.default.removeItem(at: movieURL) }
            print("Error capture photo: \(error!)")
            return
        }
        
        guard let compressedData = photoData else {
            if let movieURL { try? FileManager.default.removeItem(at: movieURL) }
            print("The expected photo data isn't available.")
            return
        }
        
  
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                if let movieURL { try? FileManager.default.removeItem(at: movieURL) }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                let creationRequest = PHAssetCreationRequest.forAsset()
                creationRequest.addResource(with: .photo, data: compressedData, options: nil)
                if let livePhotoCompanionMovieURL = movieURL {
                    let livePhotoCompanionMovieFileOptions = PHAssetResourceCreationOptions()
                    livePhotoCompanionMovieFileOptions.shouldMoveFile = true
                    creationRequest.addResource(with: .pairedVideo,
                                                fileURL: livePhotoCompanionMovieURL,
                                                options: livePhotoCompanionMovieFileOptions)
                }
            } completionHandler: { success, error in
              
                
                if let error {
                    print("Error save photo: \(error)")
                }
                if let movieURL { try? FileManager.default.removeItem(at: movieURL) }
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
        try Self.validateFriendUID(friendUid)
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "PhotoSave", code: 1, userInfo: [NSLocalizedDescriptionKey: "ログイン状態を確認してください。"])
        }
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            throw NSError(domain: "PhotoSave", code: 2, userInfo: [NSLocalizedDescriptionKey: "写真を作成できませんでした。"])
        }

        let livePhotoFileName = liveurl
        let imageName = "\(UUID().uuidString).jpg"
        let imageReference = Storage.storage().reference().child("images/\(imageName)")
        do {
            _ = try await imageReference.putDataAsync(imageData)
            guard Auth.auth().currentUser?.uid == uid else {
                throw NSError(domain: "PhotoSave", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "ログイン状態が変わりました。もう一度ログインしてください。"])
            }
            let db = Firestore.firestore()
            let folder = db.collection("users").document(uid).collection("folders").document("all")
            let photo = folder.collection("photos").document()
            let record = PhotoRecord(id: photo.documentID, fileName: imageName, date: nil,
                                     music: track.map { FirebaseMusic(photoID: photo.documentID, track: $0) },
                                     livePhotoFileName: livePhotoFileName)
            let data = record.firestoreData(date: FieldValue.serverTimestamp())
            let batch = db.batch()
            batch.setData(data, forDocument: photo)
            batch.setData(["title": "all", "date": FieldValue.serverTimestamp()], forDocument: folder, merge: true)
            if !friendUid.isEmpty && friendUid != uid {
                let friendPhoto = db.collection("users").document(friendUid).collection("folders").document("all").collection("photos").document(photo.documentID)
                batch.setData(data, forDocument: friendPhoto)
            }
            try await batch.commit()
            if Auth.auth().currentUser?.uid == uid { documentId = photo.documentID }
        } catch {
            try? await imageReference.delete()
            throw error
        }
    }

    static func validateFriendUID(_ uid: String) throws {
        // An empty UID is the supported solo-photo path.
        guard uid.count <= 128, !uid.contains("/"),
              uid.rangeOfCharacter(from: .whitespacesAndNewlines.union(.controlCharacters)) == nil else {
            throw NSError(domain: "PhotoSave", code: 3,
                userInfo: [NSLocalizedDescriptionKey: "撮影相手の情報を確認してください。"])
        }
    }

    func resizeImage(_ image: UIImage, newSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { (context) in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    func uploadLivePhotoToFirebase() {
         guard let movieURL = livePhotoCompanionMovieURL,
               FileManager.default.fileExists(atPath: movieURL.path) else {
             print("No Live Photo movie to upload.")
             return
         }
         let livePhotoFileName = UUID().uuidString

         let storageRef = Storage.storage().reference().child("livephotos/\(livePhotoFileName).mov")

         storageRef.putFile(from: movieURL, metadata: nil) { (metadata, error) in
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
