import SwiftUI
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

// カメラビューを表示するためのUIViewControllerRepresentable
struct CameraView: UIViewControllerRepresentable {
    @Binding var images: [UIImage]
    @Binding var isPresentingCamera: Bool
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // UIImagePickerControllerのデリゲートを実装するためのコーディネータ
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                // 写真を撮ったらすぐにフィルターを適用する
                if let filteredImage = applySepiaFilter(to: image) {
                    parent.images.append(filteredImage)
                } else {
                    // フィルター適用に失敗した場合はオリジナルの画像を追加
                    parent.images.append(image)
                }
            }
            parent.isPresentingCamera = false
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresentingCamera = false
        }
    }
}

// 写真にセピアフィルターを施すための関数
func applySepiaFilter(to inputImage: UIImage) -> UIImage? {
    let context = CIContext()
    let sepiaFilter = CIFilter.sepiaTone()
    guard let ciImage = CIImage(image: inputImage) else { return nil }
    
    sepiaFilter.inputImage = ciImage
    sepiaFilter.intensity = 0.8
    
    if let outputImage = sepiaFilter.outputImage, let cgimg = context.createCGImage(outputImage, from: outputImage.extent) {
        return UIImage(cgImage: cgimg)
    }
    return nil
}


