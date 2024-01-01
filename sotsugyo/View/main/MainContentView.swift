import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct MainContentView: View {
    var authenticationManager = AuthenticationManager()
    
    
    @ObservedObject private var cameraManager = CameraManager()
    @StateObject private var viewModel = MainContentModel()
    
    
    var body: some View {
        NavigationView {
            VStack {
                if authenticationManager.isSignIn == false {
                    SignInView(viewModel: viewModel)
                } else {
                    SignInedView(viewModel: viewModel, cameraManager: cameraManager)
                }
            }
            .background(Color(red: 229 / 255, green: 217 / 255, blue: 255 / 255, opacity: 1.0))
            .navigationTitle("チェキ一覧")
        }
    }
    
}
