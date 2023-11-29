//
//  ContentView.swift
//  sotsugyo
//
//  Created by saki on 2023/10/29.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseAuthUI
import Firebase
import FirebaseStorage

struct MainContentView: View {
   
    private var authenticationManager = AuthenticationManager()
    private let gridItemLayout = [GridItem(.flexible()), GridItem(.flexible())]
    
    @ObservedObject private var cameraManager = CameraManager()
    @StateObject private var viewModel = MainContentModel()
    
    var body: some View {
        VStack {
            
            if authenticationManager.isSignIn == false {
                
                HStack {
                    Spacer()
                    //Sign-Out状態なのでSign-Inボタンを表示する
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
                    //Sign-In状態なのでSign-Outボタンを表示する
                    
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
                    Camera2View(isPresentingCamera:  $viewModel.isPresentingCamera, cameraManager: cameraManager)
                }
                ScrollView {
                    
                    LazyVGrid(columns: gridItemLayout, spacing: 10) {
                        ForEach($viewModel.images.indices, id: \.self) { index in
                            Image(uiImage: viewModel.images[index])
                                .resizable()
                                .scaledToFit()
                                .frame(width: 150, height: 200) // 画像のサイズを指定
                                .clipped()
                        }
                    }

                }
                .refreshable {
                    Task{
                        do{
                            try await viewModel.getUrl()
                        }
                    }
                    
                }
                .onReceive(cameraManager.$newImage){ newImage in
                    if let newImage = newImage{
                        //     self.images.append(newImage)
                    }
                }
                
                
                
                
            }
            
            Spacer()
                .sheet(isPresented: $viewModel.isShowSheet) {
                    LoginView()
                    
                    
                }
                .onAppear {
                    
                    Task {
                        try await  viewModel.firstgetUrl()
                    }
                }
        }
    }
}

#Preview {
    MainContentView()
}
