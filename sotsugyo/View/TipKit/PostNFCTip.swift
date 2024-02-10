//
//  PostNFCTip.swift
//  PIcTune
//
//  Created by saki on 2024/02/02.
//

import Foundation
import TipKit

struct PostNFCTip: Tip {
    
    var title: Text {
        Text("NFC")
    }
    
    var message: Text? {
        Text("NFCカードにアルバムを保存できます")
    }
    var options: [TipOption] {
        [MaxDisplayCount(1)]
    }
    var rules: [Rule] {
        #Rule(SettingTip.openCamera) { $0.donations.count >= 12 }
    }
    
}
