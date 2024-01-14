import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct MainContentView: View {
    var authenticationManager = AuthenticationManager()
    
    @ObservedObject private var cameraManager = CameraManager()
    @StateObject private var viewModel = MainContentModel()
    @StateObject private var Color =  ColorModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack {
                    if authenticationManager.isSignIn == false {
                        SignInView(viewModel: viewModel, Color: Color)
                    } else {
                        ContentView(viewModel: viewModel, cameraManager: cameraManager, selectedFolderIndex: .constant(0), isPresentingCamera: $viewModel.isPresentingCamera, DocumentId: .constant(""))
                    }
                    
                }
                
            }
        }
    }
    
}
