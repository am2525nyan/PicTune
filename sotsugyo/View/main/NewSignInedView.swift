import SwiftUI

/// The library tab always shows photos from the special `all` folder.
struct ContentView: View {
    @ObservedObject var viewModel: MainContentModel
    @ObservedObject var cameraManager: CameraManager
    @Binding var isPresentingCamera: Bool
    @StateObject private var color = ColorModel()

    @State private var showQRAlert = false
    @State private var isPresentingQR = false

    var body: some View {
        ZStack {
            color.backGroundColor().ignoresSafeArea()

            ScrollView {
                MainImageView(viewModel: viewModel, folderId: "all")
                    .padding(.horizontal, 12)
            }
            .refreshable {
                try? await viewModel.firstgetUrl()
            }
        }
        .navigationTitle("写真")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ButtonView(
                    isPresentingCamera: $isPresentingCamera,
                    showQRAlart: $showQRAlert,
                    isPresentingQR: $isPresentingQR
                )
            }
        }
        .fullScreenCover(isPresented: $isPresentingCamera) {
            CameraView(isPresentingCamera: $isPresentingCamera, cameraManager: cameraManager, isPresentingSearch: .constant(true), friendUid: .constant(""))
        }
        .sheet(isPresented: $isPresentingQR) {
            FriendQRView(isPresentingCamera: $isPresentingCamera, cameraManager: cameraManager, isPresentingQR: $isPresentingQR, friendUid: "")
        }
        .onAppear {
            Task {
                try? await viewModel.firstgetUrl()
                try? await viewModel.getFolder()
            }
        }
    }
}

#Preview {
    NavigationStack {
        ContentView(viewModel: MainContentModel(), cameraManager: CameraManager(), isPresentingCamera: .constant(false))
    }
}
