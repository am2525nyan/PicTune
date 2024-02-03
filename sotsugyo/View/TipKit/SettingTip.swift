//
//  SettingTip.swift
//  PIcTune
//
//  Created by saki on 2024/02/03.
//

import Foundation
import TipKit

struct SettingTip: Tip {
   
    static let openCamera = Event(id: "openCamera")

    var title: Text {
        Text("設定")
    }

    var message: Text? {
        Text("名前を設定しましょう！")
    }
    var image: Image? {
            Image(systemName: "pencil")
        }
    var options: [TipOption] {
           [MaxDisplayCount(1)]
       }
    var rules: [Rule] {
           #Rule(Self.openCamera) { $0.donations.count >= 3 }
       }
       
       // [...] title, message, asset, actions, etc.
       
   

    
}
