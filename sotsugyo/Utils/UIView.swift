//
//  UIImage.swift
//  sotsugyo
//
//  Created by saki on 2023/11/29.
//

import Foundation
import UIKit

extension UIView {
    var snapshot: UIImage? {
        UIGraphicsBeginImageContextWithOptions(bounds.size, false, UIScreen.main.scale)
        defer { UIGraphicsEndImageContext() }
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        layer.render(in: context)
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
