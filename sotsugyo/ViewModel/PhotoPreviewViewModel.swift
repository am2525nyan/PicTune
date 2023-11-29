//
//  PhotoPreviewViewModel.swift
//  sotsugyo
//
//  Created by saki on 2023/11/29.
//

import Foundation
import Combine
import UIKit
class PhotoPreviewViewModel: ObservableObject {
    @Published internal var isPresentingImagePicker = false
    @Published internal var screenshotImage: UIImage?
    
    func takeScreenshot() {
        if let window = UIApplication.shared.windows.first {
            let screenshotRect = CGRect(x: 4, y: 158, width: UIScreen.main.bounds.width * 0.988, height: UIScreen.main.bounds.height * 0.726)
            
            UIGraphicsBeginImageContextWithOptions(screenshotRect.size, false, UIScreen.main.scale)
            window.drawHierarchy(in: CGRect(origin: CGPoint(x: -screenshotRect.origin.x, y: -screenshotRect.origin.y), size: window.bounds.size), afterScreenUpdates: true)
            let screenshotImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            self.screenshotImage = screenshotImage
            
            isPresentingImagePicker = true
        }
    }
    
}
