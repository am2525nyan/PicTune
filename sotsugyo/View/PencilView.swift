//
//  PenKitViewModel.swift
//  sotsugyo
//
//  Created by saki on 2023/11/29.
//

import SwiftUI

struct PencilView: View {
    @Binding var isPencilKitVisible : Bool
    @State private var penKitView = PenKitView(isPencilKitVisible: .constant(false))
    
    var body: some View {
        if isPencilKitVisible {
            penKitView
                .onAppear {
                    penKitView.changepenkit(isPencilKitVisible: isPencilKitVisible)
                }
                .transition(.opacity)
        } else {
            // 何か別の View を表示したい場合はここに追加
            StampView(selectedImage:.constant(""))
                .transition(.opacity)
                .offset(x: 0, y: 290)
        }
        
    }
    
}
#Preview {
    PencilView(isPencilKitVisible:  .constant(false))
}
