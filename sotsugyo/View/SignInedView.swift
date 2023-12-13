//
//  SignInedView.swift
//  sotsugyo
//
//  Created by saki on 2023/12/13.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore


struct CameraFolderView: View {
    @Binding var isPresentingCamera: Bool
    @Binding var showAlart: Bool
    @Binding var folderBuf: String
    @StateObject var cameraManager: CameraManager
    @ObservedObject var viewModel: MainContentModel

    var body: some View {
        HStack {
            Button("カメラ起動") {
                isPresentingCamera = true
            }
            Button("フォルダ作成") {
                showAlart = true
            }
            .alert("フォルダを制作", isPresented: $showAlart) {
                TextField("フォルダ名", text: $folderBuf)
                Button("OK", role: .cancel){
                    folderBuf = ""
                    showAlart = false
                    viewModel.makeFolder(folderName: folderBuf)
                }
                Button("Cancel", role: .destructive){
                }
            } message: {
                Text("フォルダ名を入力")
            }
        }
        .fullScreenCover(isPresented: $isPresentingCamera) {
            Camera2View(isPresentingCamera: $isPresentingCamera, cameraManager: cameraManager, isPresentingSearch: .constant(true))
        }
    }
}
struct MainImageView: View {
    @Binding var selectedImage: UIImage?
    @Binding var selectedIndex: Int
    @Binding var tapdocumentId: String
    @ObservedObject var viewModel: MainContentModel
    @Binding var selectedFolderIndex: Int
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 3) {
                ForEach($viewModel.images.indices, id: \.self) { index in
                  
                    imageCell(index: index, selectedFolderIndex: $selectedFolderIndex)
                }
            }
        }
        .onChange(of: viewModel.getimage) {
            Task {
                do {
                    try await viewModel.FoldergetUrl(folderId: selectedFolderIndex)

                               // 画像の取得が完了したら、getimageをfalseに設定
                    
                    
                } catch {
                    print("Error: \(error)")
                }
            }
        }
    }
    
    
    private func imageCell(index: Int, selectedFolderIndex: Binding<Int>) -> some View {
        NavigationLink(
            destination: ImageDetailView(image: $selectedImage, documentId: $tapdocumentId, tapdocumentId: $tapdocumentId, viewModel: viewModel, selectedIndex: selectedIndex),
            tag: viewModel.images[index],
            selection: $selectedImage,
            label: {
                Image(uiImage: viewModel.images[index])
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 350)
                    .clipped()
                    .onTapGesture {
                        tapdocumentId = viewModel.documentIdArray[index]
                        selectedImage = viewModel.images[index]
                        selectedIndex = index
                    }
                    .contextMenu {
                        ForEach(viewModel.folders.indices, id: \.self) { index1 in
                            Button {
                                // 更新された引数を渡す
                                viewModel.appendFolder(folderId: index1, index: index, selectedFolderIndex: $selectedFolderIndex)
                            } label: {
                                Text(viewModel.folders[index1] as! String)
                            }
                        }
                    }
            }
            
        )
        
    }
}



struct SignInedView: View {
    @ObservedObject var viewModel: MainContentModel
    @ObservedObject var cameraManager: CameraManager
    @State private var selectedImage: UIImage?
    @State private var selectedIndex = 0
    @State private var tapDocumentId = ""
    @State private var showAlart = false
    @State private var folderBuf = ""
@State var first = true
    var authenticationManager = AuthenticationManager()
    var body: some View {
        VStack {
            HStack {
                       Button {
                           authenticationManager.signOut()
                       } label: {
                           Text("Sign-Out")
                       }
                   }
            CameraFolderView(
                isPresentingCamera: $viewModel.isPresentingCamera,
                showAlart: $showAlart,
                folderBuf: $folderBuf,
                cameraManager: cameraManager,
                viewModel: viewModel
            )
            FolderContentView(viewModel: viewModel, selectedFolderIndex: $selectedIndex)

            MainImageView(
                selectedImage: $selectedImage,
                selectedIndex: $selectedIndex,
                tapdocumentId: $tapDocumentId,
                viewModel: viewModel,  selectedFolderIndex: $selectedIndex
            )
            Spacer()
               
                .onAppear {
                    Task {
                        if first {
                           try await viewModel.firstgetUrl()
                            try await viewModel.getDate()
                            try await viewModel.getFolder()
                          first = false
                        } else {
                           try await viewModel.getUrl()
                            try await viewModel.getFolder()
                        }
                    }
                }
        }
    }
}

struct FolderContentView: View {
    @ObservedObject var viewModel: MainContentModel
    @Binding var selectedFolderIndex: Int

    var body: some View {
        ScrollView(.horizontal) {
            HStack {
                ForEach(viewModel.folders.indices, id: \.self) { folderIndex in
                    Button {
                        selectedFolderIndex = folderIndex
                        print(selectedFolderIndex,viewModel.getimage)
                       
                        Task {
                            do {
                                
                                if selectedFolderIndex == folderIndex {
                                    viewModel.getimage.toggle()
                                }
                            }
                        }

                      
                    } label: {
                        Text(viewModel.folders[folderIndex] as! String)
                    }
                    .padding()
                    .background(selectedFolderIndex == folderIndex ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
    }
}

