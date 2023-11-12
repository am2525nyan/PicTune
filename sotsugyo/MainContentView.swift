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
    @State private var isShowSheet = false
    @State private var user: User?
    @State private var error: Error?
    @State private var images: [UIImage] = []
    @State private var isPresentingCamera = false
    private let gridItemLayout = [GridItem(.flexible()), GridItem(.flexible())]
    @State var documentId: String?

       
    
    var body: some View {
        VStack {
            
            if authenticationManager.isSignIn == false {
                
                HStack {
                    Spacer()
                    //Sign-Out状態なのでSign-Inボタンを表示する
                    Button {
                        self.isShowSheet.toggle()
                        saveUserData()
                        
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
                ScrollView {
                    
                    LazyVGrid(columns: gridItemLayout, spacing: 10) {
                        ForEach(images, id: \.self) { image in
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 200, height: 150) // 画像のサイズを指定
                                .clipped()
                        }
                    }
                }
                
                Button("カメラを開く") {
                    isPresentingCamera = true
                   
                }
                .fullScreenCover(isPresented: $isPresentingCamera) {
                    Camera2View(isPresentingCamera: $isPresentingCamera, cameraManager: CameraManager(isPresentingCamera: $isPresentingCamera, documentId: $documentId))
                    
                 
                    
                }


            }
            
            Spacer()
                .sheet(isPresented: $isShowSheet) {
                    LoginView()
                    
                    
                }
                .onAppear {
                    print("AAA")
                    Task {
                        try await getUrl()
                    }
                }
        }
    }
        
        
        func getUrl() async throws{
            print("BBB")
            let db = Firestore.firestore()
            let uid = Auth.auth().currentUser?.uid
            var urlArray = [String]()
            
            let ref = try await db.collection("users").document(uid ?? "").collection("photo").getDocuments()
            
            for document in ref.documents {
                
                let data = document.data()
                let url = data["url"]
                if url != nil{
                    urlArray.append(url as! String)
                }
                   
            }
            let storage = Storage.storage()
            
            let storageRef = storage.reference()
            for photo in urlArray{
                let imageRef = storageRef.child("images/" + photo)
                imageRef.getData(maxSize: 100 * 1024 * 1024) { data, error in
                    if let error = error {
                        print("Error occurred! : \(error)")
                    } else {
                        let image = UIImage(data: data!)
                        images.append(image!)
                        
                    }
                }
                
            }
            
        }
        
        func saveUserData(){
            
            let db = Firestore.firestore()
            
            if let currentUser = Auth.auth().currentUser {
                let uid = currentUser.uid
                db.collection("users").document(uid ).collection("personal").document("info").setData([
                    "uid": uid ,
                    "email": currentUser.email ?? "",
                    "name": currentUser.displayName ?? ""
                ]) { error in
                    if let error = error {
                        print("データの保存に失敗しました: \(error.localizedDescription)")
                    } else {
                        print("データがFirestoreに保存されました")
                    }
                }
            }
        }
        
    
}

#Preview {
    MainContentView()
}
