//
//  PencilView.swift
//  sotsugyo
//
//  Created by saki on 2023/11/24.
//

import SwiftUI
import PencilKit


struct PenKitView:UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
           return Coordinator(parent: self)
       }

    class Coordinator: NSObject, PKToolPickerObserver {
           var parent: PenKitView

           init(parent: PenKitView) {
               self.parent = parent
           }

           func toolPickerVisibilityDidChange(_ toolPicker: PKToolPicker) {
               parent.isPencilKitVisible = toolPicker.isVisible
           }
       }
    
    typealias UIViewType = PKCanvasView
    let toolPicker = PKToolPicker()
    @Binding var isPencilKitVisible: Bool
    let pkcView = PKCanvasView()
    
    func makeUIView(context: Context) -> PKCanvasView {
    
        pkcView.drawingPolicy = PKCanvasViewDrawingPolicy.anyInput
        toolPicker.addObserver(pkcView)
        toolPicker.setVisible(true, forFirstResponder: pkcView)
      
        pkcView.becomeFirstResponder()
        pkcView.isOpaque = false
        
        return pkcView
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
    }
    func changepenkit(isPencilKitVisible: Bool) {
        
               toolPicker.setVisible(isPencilKitVisible, forFirstResponder: pkcView)
   //     pkcView.drawingData = pkcView.drawing.dataRepresentation()
           
       }
   
}

