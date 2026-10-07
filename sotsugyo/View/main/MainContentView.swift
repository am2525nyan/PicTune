import SwiftUI
import FirebaseAuthUI

struct MainContentView: View {
    @StateObject private var inviteRouter = FolderInviteRouter()
    @State var authenticationManager = AuthenticationManager()
    @State private var loginError: String?
    @State private var pendingLoginError: String?
    @State private var isLoginSheetVisible = false
    
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
        .safeAreaInset(edge: .top) {
            if inviteRouter.pending != nil && !authenticationManager.isSignIn {
                Label("思い出の招待が届いています。ログイン後に受け取れます。", systemImage: "envelope.badge")
                    .font(.footnote).padding().frame(maxWidth: .infinity).background(.purple.opacity(0.1))
            }
        }
        .onOpenURL { url in
            if url.scheme == "pictune" || url.host == FolderInviteLink.host { inviteRouter.open(url, signedIn: authenticationManager.isSignIn && !viewModel.isShowSheet && !isLoginSheetVisible) }
            else { _ = FUIAuth.defaultAuthUI()?.handleOpen(url, sourceApplication: nil) }
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            if let url = activity.webpageURL { inviteRouter.open(url, signedIn: authenticationManager.isSignIn && !viewModel.isShowSheet && !isLoginSheetVisible) }
        }
        .sheet(isPresented: $viewModel.isShowSheet, onDismiss: {
            isLoginSheetVisible = false
            if let message = pendingLoginError {
                pendingLoginError = nil
                loginError = message
            } else {
                inviteRouter.resume(signedIn: authenticationManager.isSignIn)
            }
        }) {
            LoginView(viewModel: viewModel, onError: { message in
                if viewModel.isShowSheet || isLoginSheetVisible {
                    pendingLoginError = message
                    viewModel.isShowSheet = false
                } else {
                    loginError = message
                }
            })
            .onAppear { isLoginSheetVisible = true }
        }
        .sheet(item: $inviteRouter.presented, onDismiss: { if authenticationManager.isSignIn { inviteRouter.finish() } }) { link in
            FolderInvitationView(link: link)
        }
        .alert("招待リンク", isPresented: Binding(get: { inviteRouter.error != nil }, set: { if !$0 { inviteRouter.error = nil } })) {
            Button("閉じる", role: .cancel) { }
        } message: { Text(inviteRouter.error ?? "") }
        .alert("ログインできませんでした", isPresented: Binding(get: { loginError != nil }, set: { if !$0 { loginError = nil } })) {
            Button("閉じる", role: .cancel) { }
        } message: { Text(loginError ?? "") }
        .onAppear { inviteRouter.resume(signedIn: authenticationManager.isSignIn) }
        .onChange(of: authenticationManager.isSignIn) { _, isSignedIn in
            if isSignedIn && (viewModel.isShowSheet || isLoginSheetVisible) {
                viewModel.isShowSheet = false
            } else {
                inviteRouter.resume(signedIn: isSignedIn)
            }
            if !isSignedIn {
                viewModel.reset()
                folderViewModel.reset()
            }
        }
    }
}


#Preview {
    MainContentView(authenticationManager: AuthenticationManager())
}
