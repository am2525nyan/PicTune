//
//  FolderTextView.swift
//  sotsugyo
//
//  Created by saki on 2023/12/16.
//

import SwiftUI
import FirebaseAuth
import SwiftyGif
import UIKit

struct FolderTextView: View {
    @ObservedObject var viewModel: MainContentModel
    @StateObject private var session = NFCSession()
    @Binding var selectedFolderIndex: Int
    @ObservedObject var userDataList: MainContentModel
    @State var isWrite = false
    @State var isNFC = false
    @State private var isAlertShown = false
    @State private var alertMessage = ""
    @Binding var folderDocument: String
    @State var playGif = true
        @State var isActive: Bool = false
    @State var isdeletefolder = false
    var gif = UIImageView()
    let gifData = NSDataAsset(name:"heart3")?.data
    var body: some View {
        
        
        
        VStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                
                VStack(alignment: .center, spacing: 0) {
                    HStack(alignment: .center, spacing: 8) {
                        
                        
                        VStack(alignment: .leading, spacing: 0) {
                            if viewModel.folders.indices.contains(selectedFolderIndex) {
                                Text(viewModel.folders[selectedFolderIndex])
                                    .font(.custom("Roboto", size: 14))
                                    .foregroundColor(Color(red: 0, green: 0, blue: 0))
                                
                            } else {
                                ZStack{
                                    
                                    if let gifData = gifData {
                                        GIFImage(data: gifData)
                                            .frame(height: 100)
                                    }
                                    Text("読み込み中")
                                        .font(.custom("Roboto", size: 14))
                                        .foregroundColor(Color(red: 0, green: 0, blue: 0))
                                }
                            }
                            
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                HStack(alignment: .top, spacing: 8) {
                    if viewModel.folders.indices.contains(selectedFolderIndex) {
                        if viewModel.folders[selectedFolderIndex] != "all"{
                    VStack(alignment: .center, spacing: 0) {
                       
                            
                          
                                Button {
                                    isdeletefolder.toggle()
                                  
                                } label: {
                                    Text("フォルダ削除")
                                        .font(.custom("Roboto", size: 16))
                                        .foregroundColor(Color(red: 0, green: 0, blue: 0))
                                        .frame(width: 120, height: 30)
                                      
                                    
                                }
                                .alert("フォルダ削除", isPresented: $isdeletefolder) {
                                    Button("する", role: .cancel){
                                        viewModel.deletefolder()
                                    }
                                    Button("しない", role: .destructive){
                                        isdeletefolder.toggle()
                                    }
                                } message: {
                                    Text("このフォルダを削除しますか？")
                                }
                            }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color(red: 1, green: 1, blue: 1))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(red: 0, green: 0, blue: 0), lineWidth: 1))
                        }
                   
                        
                    }
                  
                    if viewModel.folders.indices.contains(selectedFolderIndex) {
                    VStack(alignment: .center, spacing: 0) {
                       
                            Button {
                                isWrite = true
                            } label: {
                                Text("フォルダに\n文字追加")
                                    .font(.custom("Roboto", size: 13))
                                    .foregroundColor(Color(red: 1, green: 1, blue: 1))
                                    .frame(width: 120, height: 30)
                            }
                        }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color(red: 0, green: 0, blue: 0))
                    .cornerRadius(8)
                   
                    }
                   
                }
                
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.vertical, 10)
                if viewModel.folders.indices.contains(selectedFolderIndex) {
                HStack(alignment: .top, spacing: 8) {
                   
                    VStack(alignment: .center, spacing: 4) {
                      
                            Button {
                                isNFC .toggle()
                            } label: {
                                Text("NFCにデータ追加")
                                    .font(.custom("Roboto", size: 12))
                                    .foregroundColor(Color(red: 0, green: 0, blue: 0))
                                    .frame(width: 240, height: 20)
                            }
                            
                            
                            .alert("コード交換", isPresented: $isNFC) {
                                
                                Button("する", role: .cancel){
                                    if let currentUser = Auth.auth().currentUser {
                                        let uid = currentUser.uid
                                        session.startWriteSession(UserUid: uid, folder: folderDocument) { error in
                                            if let error = error {
                                                alertMessage = error.localizedDescription
                                                isAlertShown = true
                                            }
                                        }
                                    }
                                }
                                Button("しない", role: .destructive){
                                    isNFC.toggle()
                                }
                            } message: {
                                Text("このフォルダをNFCカードに入れますか？")
                            }
                            .alert(isPresented: $isAlertShown) {
                                Alert(
                                    title: Text(""),
                                    message: Text(alertMessage),
                                    dismissButton: .default(Text("OK")))
                            }
                        }
                    }
                .padding(.all, 8)
                .frame(maxWidth: .infinity, alignment: .top)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(red: 0, green: 0, blue: 0, opacity: 0.10), lineWidth: 1))
                }

            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            
            
            
        
        }
        
       
            Text(userDataList.userDataList)
            
        
        .sheet(isPresented: $isWrite){
            WriteLetterView(isWrite: $isWrite, viewModel: viewModel, userDataList: userDataList)
        }
        
    }
    
}


class UIGIFImageView: UIView {
    private var image = UIImage()
    var imageView = UIImageView()
    private var data: Data?
    private var name: String?
    private var loopCount: Int?
    private var playGif: Bool?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    convenience init(name: String, loopCount: Int, playGif: Bool) {
        self.init()
        self.name = name
        self.loopCount = loopCount
        self.playGif = playGif
        self.layoutSubviews()
    }
    
    convenience init(data: Data, loopCount: Int, playGif: Bool) {
        self.init()
        self.data = data
        self.loopCount = loopCount
        self.playGif = playGif
        self.layoutSubviews()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds
        self.addSubview(imageView)
    }
    
    func updateGIF(name: String, data: Data?, loopCount: Int) {
        do {
            if let data = data {
                image = try UIImage(gifData: data)
            } else {
                print(name)
                image = try UIImage(gifName: name)
            }
        } catch {
            print(error)
        }
        
        if let subview = self.subviews.first as? UIImageView {
            if image.imageData != subview.gifImage?.imageData {
                imageView = UIImageView(gifImage: image, loopCount: loopCount)
                imageView.contentMode = .scaleAspectFit
                subview.removeFromSuperview()
            }
        } else {
            print("error: no existing subview")
        }
    }
}
struct GIFImage: UIViewRepresentable {
    private let data: Data?
    private let name: String?
    private let loopCount: Int?
    @Binding var playGif: Bool
    
    init(data: Data, loopCount: Int = -1, playGif: Binding<Bool> = .constant(true)) {
        self.data = data
        self.name = nil
        self.loopCount = loopCount
        self._playGif = playGif
    }
    
    init(name: String, loopCount: Int = -1, playGif: Binding<Bool> = .constant(true)) {
        self.data = nil
        self.name = name
        self.loopCount = loopCount
        self._playGif = playGif
    }
    
    func makeUIView(context: Context) -> UIGIFImageView {
        var gifImageView: UIGIFImageView
        if let data = data {
            gifImageView = UIGIFImageView(data: data, loopCount: loopCount!, playGif: playGif)
        } else {
            gifImageView = UIGIFImageView(name: name!, loopCount: loopCount!, playGif: playGif)
        }
        return gifImageView
    }
    
    func updateUIView(_ gifImageView: UIGIFImageView, context: Context) {
        gifImageView.updateGIF(name: name ?? "", data: data, loopCount: loopCount!)
        
        if playGif {
            gifImageView.imageView.startAnimatingGif()
        } else {
            gifImageView.imageView.stopAnimatingGif()
        }
    }
}

