import SwiftUI
import ARKit
import SceneKit

struct PhotoPreviewView: View {
    var images: UIImage?
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
    
    var body: some View {
        ZStack{
            Color.backGroundColor().edgesIgnoringSafeArea(.all)
            VStack {
                if let image = images {
                    HStack{
                        Button("保存") {
                            viewModel.takeScreenshot()
                            UIImageWriteToSavedPhotosAlbum(viewModel.screenshotImage ?? image, nil, nil, nil)
                            cameraManager.uploadPhoto(viewModel.screenshotImage ?? image, friendUid: friendUid)
                        }
                        Button(action: {
                            self.isPencilKitVisible.toggle()
                        }) {
                            Text(isPencilKitVisible ? "Hide PencilKit" : "Show PencilKit")
                        }
                        .foregroundColor(.blue)
                        .padding()
                        
                        .sheet(isPresented: $isPresentingSearch) {
                            SearchView(documentId: documentId, friendUid: $friendUid)
                        }
                    }
                    ZStack{
                        Image("Image")
                            .resizable()
                            .scaledToFit()
                            .overlay {
                                Image(uiImage: image)
                                    .resizable()
                                    .frame(width: previewWidth, height: previewHeight)
                                    .position(x: 195, y: 286)
                            }
                        Image(selectedImageManager.selectedImage ?? "1")
                            .resizable()
                            .frame(width: previewWidth * 1.15, height: previewHeight * 1.325)
                            .position(x: 194, y: 335)
                          
                           
                           
                        
                        PencilView(isPencilKitVisible: $isPencilKitVisible)
                    }
                    
                } else {
                  
                        
                    Text("写真がありません")
                }
            }
            
            
            
        }
    }
}
#Preview{
    PhotoPreviewView(isPresentingCamera: .constant(false), isPresentingSearch: .constant(false), documentId: .constant(""), cameraManager: CameraManager(), friendUid: .constant(""))
}
