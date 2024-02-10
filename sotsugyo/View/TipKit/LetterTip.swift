//
//  LetterTip.swift
//  PIcTune
//
//  Created by saki on 2024/02/02.
//

import Foundation
import TipKit

struct LetterTip: Tip {
    
    var title: Text {
        Text("手紙")
    }
    
    var message: Text? {
        Text("フォルダに手紙を書いたり見ることができます")
    }
    var image: Image? {
        Image(systemName: "rectangle.and.pencil.and.ellipsis")
    }
    var options: [TipOption] {
        [MaxDisplayCount(1)]
    }
    var rules: [Rule] {
        #Rule(SettingTip.openCamera) { $0.donations.count >= 6 }
    }
}
