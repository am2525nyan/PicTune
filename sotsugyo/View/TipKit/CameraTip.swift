//
//  CameraTip.swift
//  PIcTune
//
//  Created by saki on 2024/02/02.
//

import Foundation
import TipKit

struct CameraTip: Tip {

    var title: Text {
        Text("カメラ")
    }

    var message: Text? {
        Text("カメラを起動して、チェキを撮影します。友達がアプリを持っている場合はするを押してください。")
    }

    var image: Image? {
            Image(systemName: "camera.fill")
        }
}
