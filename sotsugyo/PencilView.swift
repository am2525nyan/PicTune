//
//  PencilView.swift
//  sotsugyo
//
//  Created by saki on 2023/11/24.
//

import SwiftUI
import PencilKit
struct PencilView: View {
    var body: some View {
        PenKitView()
        
    }
}

struct PenKitView:UIViewRepresentable {
   typealias UIViewType = PKCanvasView
    let toolPicker = PKToolPicker()
   
   func makeUIView(context: Context) -> PKCanvasView {
       let pkcView = PKCanvasView()
       pkcView.drawingPolicy = PKCanvasViewDrawingPolicy.anyInput
       toolPicker.addObserver(pkcView)
       toolPicker.setVisible(true, forFirstResponder: pkcView)
       pkcView.becomeFirstResponder()
       pkcView.isOpaque = false
       
       return pkcView
   }
   
   func updateUIView(_ uiView: PKCanvasView, context: Context) {
   }
   
}


