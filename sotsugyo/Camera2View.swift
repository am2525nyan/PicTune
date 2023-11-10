//
//  Camera2View.swift
//  sotsugyo
//
//  Created by saki on 2023/11/06.
//

import SwiftUI

struct Camera2View: View {
    @Binding var isPresentingCamera: Bool
    @ObservedObject var cameraManager: CameraManager
    @Environment(\.presentationMode) var presentation
    @State private var isPresentingMain = false

    init(isPresentingCamera: Binding<Bool>, cameraManager: CameraManager) {
        self._isPresentingCamera = isPresentingCamera
        self.cameraManager = cameraManager
        self.cameraManager.setupCaptureSession()
    }
    
    


    var body: some View {
        ZStack {
            CameraPreview(cameraManager: cameraManager)
            VStack {
                Spacer()
                Button("撮影") {
  
                    cameraManager.captureImage()
                  
                }
                
                .padding()
                .onChange(of: cameraManager.isImageUploadCompleted) { completed in
                          if completed {
                              // Firestoreへのアップロードが完了したら、isPresentingCamera を false にしてシートを閉じる
                              self.isPresentingCamera = false
                          }
                      }
            }
        }
        .onAppear {
        
            cameraManager.startSession()
        }
        .onDisappear {
          //  cameraManager.stopSession()
        }
    }
}

