import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

struct CameraView: View {
    @State private var isShowingImagePicker = false
    @State private var image: Image?
    @State private var filteredImage: Image?

    var body: some View {
        VStack {
            Button("カメラを起動") {
                self.isShowingImagePicker = true
            }
            if let displayImage = filteredImage ?? image {
                displayImage
                    .resizable()
                    .scaledToFit()
            }
        }
        .sheet(isPresented: $isShowingImagePicker) {
            ImagePicker(image: self.$image) { uiImage in
                applyFilter(to: uiImage)
            }
        }
    }

    func applyFilter(to uiImage: UIImage) {
        filteredImage = Image(uiImage: uiImage.applyingFilterWithFixedColor()!)
    }
}



extension UIImage {
    func applyingFilterWithFixedColor() -> UIImage? {
        guard let ciImage = CIImage(image: self) else {
            return nil
        }

        let filter = CIFilter.colorMonochrome()
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        
        // 指定した色（例：赤色）をフィルターに適用
        filter.setValue(CIColor(red: 1.0, green: 0.0, blue: 0.0), forKey: kCIInputColorKey)
        
        if let outputImage = filter.outputImage {
            let context = CIContext()
            if let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
                return UIImage(cgImage: cgImage)
            }
        }
        return nil
    }
}
