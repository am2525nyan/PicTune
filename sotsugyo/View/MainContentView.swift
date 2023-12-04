//
//  ContentView.swift
//  sotsugyo
//
//  Created by saki on 2023/10/29.
//


import SwiftUI

struct MainContentView: View {
  var authenticationManager = AuthenticationManager()
    private let gridItemLayout = [GridItem(.flexible()), GridItem(.flexible())]

    @ObservedObject private var cameraManager = CameraManager()
    @StateObject private var viewModel = MainContentModel()
    
    var body: some View {
        VStack {
            if authenticationManager.isSignIn == false {
                HStack {
                    Spacer()
                    Button {
                        viewModel.isShowSheet.toggle()
                        viewModel.saveUserData()
                    } label: {
                        Text("Sign-In")
                    }
                    .padding()
                }
            } else {
                HStack {
                    Button {
                        authenticationManager.signOut()
                    } label: {
                        Text("Sign-Out")
                    }
                }
                Button("Open Camera") {
                    viewModel.isPresentingCamera = true
                    
                }
                .fullScreenCover(isPresented: $viewModel.isPresentingCamera) {
                    Camera2View(isPresentingCamera: $viewModel.isPresentingCamera, cameraManager: cameraManager, isPresentingSearch: .constant(true))
                }
                ScrollView {
                    LazyVGrid(columns: gridItemLayout, spacing: 10) {
                        ForEach($viewModel.images.indices, id: \.self) { index in
                            Image(uiImage: viewModel.images[index])
                                .resizable()
                                .scaledToFit()
                                .frame(width: 150, height: 200)
                                .clipped()
                        }
                    }
                }
                .refreshable {
                    Task {
                        do {
                            try await viewModel.getUrl()
                        }
                    }
                }
                .onReceive(cameraManager.$newImage) { newImage in
                    if newImage != nil {
                        // self.images.append(newImage)
                    }
                }
            }

            Spacer() 
                .sheet(isPresented: $viewModel.isShowSheet) {
                    LoginView()
                }
                .onAppear {
                    Task {
                        try await viewModel.firstgetUrl()
                    }
                }
        }
    }
}
