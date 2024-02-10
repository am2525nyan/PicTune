//
//  PhotoPreviewViewModel.swift
//  sotsugyo
//
//  Created by saki on 2023/11/29.
//

import Foundation
import Combine
import UIKit
import SwiftUI
class PhotoPreviewViewModel: ObservableObject {
    @Published internal var isPresentingImagePicker = false
    @Published internal var screenshotImage: UIImage?
    
    func takeScreenshot(geometry: GeometryProxy) {
       
            if let window = UIApplication.shared.windows.first {
                let positionX = geometry.frame(in: .global).midX
                let positionY = geometry.frame(in: .global).midY
                
                let screenshotRect = CGRect(x: positionX - 335 / 2,
                                            y: positionY - 525 / 2 - 40, // 調整した値
                                            width: 333,
                                            height: 525)
                
                UIGraphicsBeginImageContextWithOptions(screenshotRect.size, false, UIScreen.main.scale)
                window.drawHierarchy(in: CGRect(origin: CGPoint(x: -screenshotRect.origin.x, y: -screenshotRect.origin.y), size: window.bounds.size), afterScreenUpdates: true)
                let screenshotImage = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                
                self.screenshotImage = screenshotImage
                
                isPresentingImagePicker = true
            }
            
        
    }
    
}
