//
//  SignInedView.swift
//  sotsugyo
//
//  Created by saki on 2023/12/13.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SignInedView: View {
    @ObservedObject var viewModel: MainContentModel
    @ObservedObject var cameraManager: CameraManager
    var authenticationManager = AuthenticationManager()
    private let gridItemLayout = [GridItem(.flexible()), GridItem(.flexible())]
    // タップされた画像を保持するための State 変数を追加
    @State var selectedImage: UIImage?
    @State var selectedIndex = Int()
    @State var dates  = [String]()
    @State var tapdocumentId = String()
    @State private var Music: [FirebaseMusic] = []
    @State var documentIdArray = []
    @State var first = true
    @State var folderUrl = String()
    @State var showAlart = false
    @State var folder = String()
    @State var folders = [String]()
    @State var foldersDocumentId = [String]()
    //バッファとする
    @State private var folderBuf = ""
    var body: some View {
        HStack {
            Button {
                authenticationManager.signOut()
            } label: {
                Text("Sign-Out")
            }
        }
        HStack {
            Button("カメラ起動") {
                viewModel.isPresentingCamera = true
                
            }
            Button("フォルダ作成") {
                showAlart = true
                
            }.alert("フォルダを制作", isPresented: $showAlart) {
                TextField("フォルダ名", text: $folderBuf)
                Button("OK", role: .cancel){
                    //OKで値を渡す
                    folder.append(folderBuf)
                    viewModel.makeFolder(folderName: folderBuf)
                    folderBuf = ""
                    showAlart = false
                    folders.append(folderBuf)
                }
                Button("Cancel", role: .destructive){
                    
                }
            } message: {
                Text("フォルダ名を入力")
            }
            
            
        }
        .fullScreenCover(isPresented: $viewModel.isPresentingCamera) {
            Camera2View(isPresentingCamera: $viewModel.isPresentingCamera, cameraManager: cameraManager, isPresentingSearch: .constant(true))
        }
        
        ScrollView {
            LazyVGrid(columns: gridItemLayout, spacing: 3) {
                ForEach($viewModel.images.indices, id: \.self) { index in
                    // 画像を NavigationLink でラップ
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
                                    tapdocumentId  = viewModel.documentIdArray[index] 
                                    selectedImage = viewModel.images[index]
                                    selectedIndex = index
                                }
                                .contextMenu {
                                    ForEach(folders.indices, id: \.self) { index1 in
                                        let folderId = folders[index1]

                                        Button {
                                            print("aaa",folder,folderId,index,"aaa")
                                            appendFolder(folderId: index1, index: index)
                                        } label: {
                                            Text(folders[index1])
                                        }
                                    }
                                }

                            
                        }
                        
                    )
                    
                    
                    
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
        
        
        Spacer()
            .sheet(isPresented: $viewModel.isShowSheet) {
                LoginView()
            }
            .onAppear {
                folderUrl = "Main"
                Task {
                    if first == true{
                        try await viewModel.firstgetUrl()
                        try await viewModel.getDate()
                        try await  getFolder()
                        
                        first = false
                    }else{
                        try await viewModel.getUrl()
                        try await  getFolder()
                    }
                    
                }
            }
        
    }
    
    
    func getFolder()async throws{
        DispatchQueue.main.async {
            self.folders = []
        }
        let db = Firestore.firestore()
        
        if let currentUser = Auth.auth().currentUser {
            let uid = currentUser.uid
            
            let ref =  try await db.collection("users").document(uid).collection("folders").getDocuments()
            for document in ref.documents {
                let data = document.data()
                let folder = data["title"] as! String
                let documentId = document.documentID
                DispatchQueue.main.async {
                    self.folders.append(folder)
                    self.foldersDocumentId.append(documentId)
                }
            }
            
        }
    }
    func appendFolder(folderId: Int, index: Int) {
        let db = Firestore.firestore()
        let document = viewModel.documentIdArray[index]
        let folderDocument = foldersDocumentId[folderId]

        if let currentUser = Auth.auth().currentUser {
            let uid = currentUser.uid

            // 新しいコレクション名
            let newCollectionName = "photos"

            // 新しいコレクションのドキュメントリファレンスを作成
            let destinationCollectionRef = db.collection("users").document(uid).collection("folders").document(folderDocument).collection(newCollectionName).document()

            // バッチを新しく作成
            let batch = db.batch()

            // "photo" コレクションからデータを取得して新しいコレクションに追加
            let sourceDocumentRef = db.collection("users").document(uid).collection("photo").document(document)
            sourceDocumentRef.getDocument { (documentSnapshot, error) in
                if let error = error {
                    print("Error getting document: \(error)")
                } else if let data = documentSnapshot?.data() {
                    // 対応する document のデータを新しいコレクション内の新しいドキュメントにセット
                    batch.setData(data, forDocument: destinationCollectionRef)

                    // バッチをコミット
                    batch.commit() { err in
                        if let err = err {
                            print("バッチの書き込みエラー: \(err)")
                        } else {
                            print("データが正常にコピーされました！")
                        }
                    }
                }
            }
        }
    }

    }

