//
//  cameranowView.swift
//  PIcTune
//
//  Created by saki on 2024/02/14.
//

import Foundation
//
//  CameraTip.swift
//  PIcTune
//
//  Created by saki on 2024/02/02.
//

import Foundation
import TipKit

struct CameraNowTip: Tip {
    
    var title: Text {
        Text("カメラ")
    }
    
    var message: Text? {
        Text("撮影中はここが赤く光ります")
    }
    
    var image: Image? {
        Image(systemName: "camera.fill")
        
    }
    
    var options: [TipOption] {
        [MaxDisplayCount(1)]
    }
}
