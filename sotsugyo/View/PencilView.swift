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
        VStack{
            penKitView // ここを変更
            
            
            if !isPencilKitVisible {
                // 何か別の View を表示したい場合はここに追加
                StampView(selectedImage:.constant(""))
                  
                    .onAppear {
                        penKitView.changepenkit(isPencilKitVisible: false) // ここを追加
                    }
                    .onDisappear {
                        penKitView.changepenkit(isPencilKitVisible: true) // ここを追加
                    }
                
            }
        }
        .onDisappear(){
            penKitView.changepenkit(isPencilKitVisible: false) // ここを追加
        }
       
        
    }
    

}
#Preview {
    PencilView(isPencilKitVisible:  .constant(false))
}
