//
//  TabView.swift
//  sotsugyo
//
//  Created by saki on 2023/11/26.
//

import SwiftUI

struct TabContentView: View {
    
    @State private var isPresentingCamera = false
    @ObservedObject private var cameraManager = CameraManager()
    @State var selection = 1

    var body: some View {
        TabView(selection: $selection) {

            MainContentView()
            
                .tabItem {
                    VStack {
                        Label("Page1", systemImage: "1.circle")
                    }
                    .tag(1)
                  }
            Camera2View(isPresentingCamera: $isPresentingCamera, cameraManager: cameraManager)
                .tabItem {
                    VStack {
                        Label("Page1", systemImage: "2.circle")
                        
                        
                    }
                    .tag(2)
                    
                    
                }
                .fullScreenCover(isPresented: $isPresentingCamera) {
                                  Camera2View(isPresentingCamera: $isPresentingCamera, cameraManager: cameraManager)
                              }
        }
    }
}
