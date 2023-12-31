//
//  QRCodeGenerator.swift
//  sotsugyo
//
//  Created by saki on 2023/12/18.
//

import SwiftUI

struct QRCodeGenerator {
    
    func generate(with inputText: String) -> UIImage? {
        
        guard let qrFilter = CIFilter(name: "CIQRCodeGenerator")
        else { return nil }
        
        let inputData = inputText.data(using: .utf8)
        qrFilter.setValue(inputData, forKey: "inputMessage")
        
        qrFilter.setValue("H", forKey: "inputCorrectionLevel")
        
        guard let ciImage = qrFilter.outputImage
        else { return nil }
        
        let sizeTransform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledCiImage = ciImage.transformed(by: sizeTransform)
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledCiImage,
                                                  from: scaledCiImage.extent)
        else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
}
