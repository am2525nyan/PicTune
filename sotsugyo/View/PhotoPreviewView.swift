import SwiftUI
import ARKit
import SceneKit

struct PhotoPreviewView: View {
    var images = UIImage(named: "1")
    @Binding var isPresentingCamera: Bool
    @Binding var isPresentingSearch: Bool
    @Binding var documentId: String
    @ObservedObject var cameraManager: CameraManager
    let previewX = CGFloat(27)
    let previewY = CGFloat(131)
    let previewWidth = UIScreen.main.bounds.width * 0.867
    let previewHeight = UIScreen.main.bounds.height * 0.537
    @Environment(\.displayScale) private var displayScale
    @Binding var friendUid: String
    
    @StateObject private var viewModel = PhotoPreviewViewModel()
    @StateObject private var mainViewModel = MainContentModel()
    @StateObject private var Color = ColorModel()
    @EnvironmentObject private var selectedImageManager: SelectedImageManager
    
    @State var isPencilKitVisible = false
    @State var selectedImage = "0"
    @State var isHidden = false
    @State var customGeometry : GeometryProxy?
    
    var body: some View {
        ZStack{
            Color.backGroundColor().edgesIgnoringSafeArea(.all)
            VStack {
                if let image = images {
                    HStack{
                        Button("保存") {
                            
                            isHidden = true
                            
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                // 透明になった後にスクリーンショットを撮影
                                viewModel.takeScreenshot(geometry: customGeometry!)
                                UIImageWriteToSavedPhotosAlbum(viewModel.screenshotImage ?? image, nil, nil, nil)
                                cameraManager.uploadPhoto(viewModel.screenshotImage ?? image, friendUid: friendUid)
                            }
                        }
                        Button(action: {
                            self.isPencilKitVisible.toggle()
                        }) {
                            Text(isPencilKitVisible ? "スタンプ" : "ペン")
                                .padding(5)
                                .background(.white)
                              
                        }
                        .foregroundColor(.blue)
                        .padding()
                        
                        .sheet(isPresented: $isPresentingSearch) {
                            SearchView(documentId: documentId, friendUid: $friendUid)
                        }
                    }
                    GeometryReader { geometry in
                        
                        ZStack {
                            Image("Image")
                                .resizable()
                                .scaledToFit()
                                .padding(.bottom, 70)
                                .frame(width: 375, height: 603)
                                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                                .overlay() {
                                    Image(uiImage: image)
                                        .resizable()
                                    
                                        .frame(width: 290,height: 388)
                                        .padding(.bottom, 110)
                                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                                    
                                    
                                    
                                    Image(selectedImageManager.selectedImage ?? "")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 338, height: 603)
                                        .position(x: geometry.size.width / 2, y: (geometry.size.height / 2) - 34)
                                    
                                }
                            
                            
                            PencilView(isPencilKitVisible: $isPencilKitVisible)
                                .opacity(isHidden ? 0 : 1)
                            
                            
                            
                        }
                        
                        .onAppear(){
                            self.customGeometry = geometry
                        }
                        
                    }
                } else {
                    
                    
                    Text("写真がありません")
                }
            }
            
            
            
        }
        .edgesIgnoringSafeArea(.all)
    }
    
}

