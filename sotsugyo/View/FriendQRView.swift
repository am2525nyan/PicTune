import SwiftUI
import FirebaseAuth
import CodeScanner

struct FriendQRView: View {
    @Binding var isPresentingCamera: Bool
    @StateObject var cameraManager: CameraManager
    @Binding var isPresentingQR: Bool
    @State var friendUid: String
    @State private var isPresentingScanner = false
    @State private var isPresentingQRCode = false
    @State private var qrCodeImage: UIImage?
    @State private var error: String?
    @State private var friendName: String?
    @State private var isLoading = false
    private let qrCodeGenerator = QRCodeGenerator()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("一緒に撮る招待").font(.title2.bold())
                Text("このコードを見せた相手から、写真を受け取れます。\nコードは15分間有効です。")
                    .font(.subheadline).multilineTextAlignment(.center)
                if let qrCodeImage { Image(uiImage: qrCodeImage).interpolation(.none).resizable().frame(width: 220, height: 220) }
                if isLoading { ProgressView() }
                if let error { Text(error).font(.footnote).foregroundStyle(.red) }
                Button("コードを更新") { Task { await createCode() } }.disabled(isLoading)
                Button("相手のQRコードを読み取る") { isPresentingScanner = true }
                    .buttonStyle(.borderedProminent).disabled(isLoading)
            }.padding(24)
            .sheet(isPresented: $isPresentingScanner) {
                CodeScannerView(codeTypes: [.qr]) { result in
                    isPresentingScanner = false
                    switch result {
                    case .success(let scan):
                        Task { @MainActor in
                            isLoading = true
                            defer { isLoading = false }
                            do {
                                let invitation = try await CameraInvitationService.accept(payload: scan.string)
                                friendUid = invitation.ownerID; friendName = invitation.name
                            } catch { self.error = "招待を確認できませんでした。最新のQRコードを読み取ってください。\n\(error.localizedDescription)" }
                        }
                    case .failure(let error): self.error = error.localizedDescription
                    }
                }
            }
            .alert("相手を確認しました", isPresented: Binding(get: { friendName != nil }, set: { if !$0 { friendName = nil } })) {
                Button("撮影する") { isPresentingQRCode = true }
                Button("キャンセル", role: .cancel) { friendUid = "" }
            } message: { Text("\(friendName ?? "")さんと撮ります。") }
            .fullScreenCover(isPresented: $isPresentingQRCode) {
                CameraView(isPresentingCamera: $isPresentingQRCode, cameraManager: cameraManager, isPresentingSearch: .constant(true), friendUid: $friendUid)
            }
            .task { await createCode() }
        }
    }
    @MainActor private func createCode() async {
        isLoading = true; error = nil
        defer { isLoading = false }
        do { qrCodeImage = qrCodeGenerator.generate(with: try await CameraInvitationService.create().payload) }
        catch { self.error = error.localizedDescription }
    }
}
