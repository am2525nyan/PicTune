import SwiftUI

struct MainContentView: View {
    @State var authenticationManager = AuthenticationManager()
    
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var viewModel = MainContentModel()
    @StateObject private var folderViewModel = MainContentModel()
    @StateObject private var Color =  ColorModel()
    
    var body: some View {
        Group {
            if authenticationManager.isSignIn == false {
                NavigationStack {
                    SignInView(viewModel: viewModel, Color: Color)
                }
            } else {
                TabView {
                    NavigationStack {
                        ContentView(viewModel: viewModel, cameraManager: cameraManager, isPresentingCamera: $viewModel.isPresentingCamera)
                    }
                    .tabItem {
                        Label("写真", systemImage: "photo.on.rectangle")
                    }

                    NavigationStack {
                        FolderLibraryView(viewModel: folderViewModel)
                    }
                    .tabItem {
                        Label("フォルダ", systemImage: "folder")
                    }

                    NavigationStack {
                        SettingView()
                    }
                    .tabItem {
                        Label("設定", systemImage: "gearshape")
                    }
                }
            }
        }
        .id(authenticationManager.userID)
        .onChange(of: authenticationManager.userID, initial: true) { previousUserID, userID in
            if previousUserID != userID || userID == nil {
                viewModel.reset()
                folderViewModel.reset()
            }
        }
    }
}


#Preview {
    MainContentView(authenticationManager: AuthenticationManager())
}
