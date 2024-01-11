//
//  Color.swift
//  sotsugyo
//
//  Created by saki on 2024/01/11.
//

import Foundation
import SwiftUI

class ColorModel: ObservableObject {
    
    func backGroundColor() -> LinearGradient {
           let start = UnitPoint.init(x: 0, y: 0)
           let end = UnitPoint.init(x: 1, y: 1)

           let colors = Gradient(colors: [Color(red: 0.78, green: 0.83, blue: 0.98),
                                          Color(red: 0.89, green: 0.75, blue: 0.99)])

           let gradientColor = LinearGradient(gradient: colors, startPoint: start, endPoint: end)

           return gradientColor
       }
    func backGroundColor2() -> LinearGradient {
        let start = UnitPoint.init(x: 0, y: 0.5)
        let end = UnitPoint.init(x: 1, y: 0.5)
        
        let colors = Gradient(colors: [ Color(red: 0.89, green: 0.75, blue: 0.99),
                                        Color(red: 0.78, green: 0.83, blue: 0.98)])
        
        let gradientColor = LinearGradient(gradient: colors, startPoint: end, endPoint: start)
        
        return gradientColor
    }
}
