import SwiftUI
import CodeScanner

struct FriendQRView: View {
    @Binding var isPresentingCamera: Bool
    @StateObject var cameraManager: CameraManager
    @Binding var isPresentingQR: Bool
    @State var friendUid: String

    private enum Mode {
        case scan
        case show
    }

    private let createInvitation: () async throws -> CameraInvitation
    private let acceptInvitation: (String) async throws -> CameraInvitation
    private let qrCodeGenerator = QRCodeGenerator()
    @State private var mode: Mode = .scan
    @State private var scannerID = UUID()
    @State private var isPresentingQRCode = false
    @State private var qrCodeImage: UIImage?
    @State private var codeError: String?
    @State private var scanError: String?
    @State private var needsCameraAccess = false
    @State private var friendName: String?
    @State private var isCreatingCode = false
    @State private var isCheckingCode = false

    init(isPresentingCamera: Binding<Bool>, cameraManager: CameraManager,
         isPresentingQR: Binding<Bool>, friendUid: String,
         createInvitation: @escaping () async throws -> CameraInvitation = CameraInvitationService.create,
         acceptInvitation: @escaping (String) async throws -> CameraInvitation = CameraInvitationService.accept) {
        _isPresentingCamera = isPresentingCamera
        _cameraManager = StateObject(wrappedValue: cameraManager)
        _isPresentingQR = isPresentingQR
        _friendUid = State(initialValue: friendUid)
        self.createInvitation = createInvitation
        self.acceptInvitation = acceptInvitation
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    if mode == .scan { scanContent }
                    else { showContent }
                }
                .frame(maxWidth: 440)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
            .background(Color(uiColor: .systemBackground))
            .navigationTitle(mode == .scan ? "QRコードを読み取る" : "QRコードを見せる")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if mode == .show {
                        Button("読み取る", systemImage: "chevron.left") { mode = .scan }
                            .accessibilityIdentifier("qr.scanMode")
                    } else {
                        Button("閉じる") { isPresentingQR = false }
                    }
                }
                if mode == .show {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("閉じる") { isPresentingQR = false }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if mode == .scan, friendName != nil {
                    Button { isPresentingQRCode = true } label: {
                        Text("撮影する")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.bar)
                    .accessibilityIdentifier("qr.takePhoto")
                }
            }
            .fullScreenCover(isPresented: $isPresentingQRCode) {
                CameraView(isPresentingCamera: $isPresentingQRCode, cameraManager: cameraManager,
                           isPresentingSearch: .constant(true), friendUid: $friendUid)
            }
            .onChange(of: isPresentingQRCode) { wasPresented, isPresented in
                if wasPresented && !isPresented { isPresentingQR = false }
            }
            .onChange(of: mode) { _, newMode in
                if newMode == .scan {
                    scannerID = UUID()
                } else if qrCodeImage == nil {
                    Task { await createCode() }
                }
            }
        }
        .tint(GiftPalette.purple)
    }

    private var scanContent: some View {
        VStack(spacing: 24) {
            if let friendName {
                VStack(spacing: 12) {
                    Text("\(friendName)さんと撮影")
                        .font(.title.bold())
                        .accessibilityIdentifier("qr.confirmedName")
                    Text("撮影した写真を相手にも届けます。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 360)
                Button("別のコードを読み取る") { resetScanner() }
            } else if isCheckingCode {
                ProgressView("招待を確認しています…")
                    .frame(maxWidth: .infinity, minHeight: 360)
            } else if let scanError {
                ContentUnavailableView("読み取れませんでした", systemImage: "qrcode.viewfinder",
                                       description: Text(scanError))
                    .accessibilityIdentifier("qr.scanError")
                if needsCameraAccess {
                    Button("設定を開く") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("もう一度読み取る") { resetScanner() }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("qr.retry")
                }
            } else {
                Text("友達のQRコードを枠に合わせてください")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                #if targetEnvironment(simulator)
                ZStack {
                    Color.black
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(.white.opacity(0.8), lineWidth: 2)
                        .frame(width: 236, height: 236)
                    Text("カメラは実機で使用できます")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.black.opacity(0.65), in: Capsule())
                }
                .frame(height: 400)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                #if DEBUG
                if UITestFixtures.isEnabled && ProcessInfo.processInfo.arguments.contains("-ui-testing-qr") {
                    Button("読み取りを試す") {
                        Task { await checkCode("ui-test-code") }
                    }
                    .accessibilityIdentifier("qr.simulateScan")
                }
                #endif
                #else
                CodeScannerView(codeTypes: [.qr], scanMode: .once, showViewfinder: true,
                                requiresPhotoOutput: false) { result in
                    switch result {
                    case .success(let scan):
                        Task { await checkCode(scan.string) }
                    case .failure(let error):
                        needsCameraAccess = { if case .permissionDenied = error { return true }; return false }()
                        scanError = needsCameraAccess
                            ? "カメラへのアクセスを許可してください。"
                            : "カメラを使用できません。もう一度お試しください。"
                    }
                }
                .id(scannerID)
                .frame(height: 400)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .accessibilityLabel("QRコード読み取りカメラ")
                #endif
            }
            if !isCheckingCode && friendName == nil {
                Button("自分のQRコードを見せる") { mode = .show }
                    .accessibilityIdentifier("qr.showMode")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var showContent: some View {
        VStack(spacing: 24) {
            if let qrCodeImage {
                Image(uiImage: qrCodeImage)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 236, height: 236)
                    .padding(24)
                    .background(.white)
                    .accessibilityLabel("友達に見せる招待QRコード")
                    .accessibilityIdentifier("qr.code")
                    .frame(maxWidth: .infinity, minHeight: 360)
            } else if isCreatingCode {
                ProgressView("QRコードを作成しています…")
                    .frame(maxWidth: .infinity, minHeight: 360)
            }
            if let codeError {
                Text(codeError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("qr.codeError")
            } else {
                Text("友達に見せてください。15分間有効です。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if !isCreatingCode {
                Button(qrCodeImage == nil ? "もう一度作成する" : "QRコードを更新") {
                    Task { await createCode() }
                }
                .accessibilityIdentifier("qr.refresh")
            }
        }
        .frame(maxWidth: .infinity)
    }

    @MainActor private func checkCode(_ payload: String) async {
        guard !isCheckingCode, friendName == nil, scanError == nil else { return }
        isCheckingCode = true
        defer { isCheckingCode = false }
        do {
            let invitation = try await acceptInvitation(payload)
            guard !Task.isCancelled, mode == .scan else { return }
            friendUid = invitation.ownerID
            friendName = invitation.name
        } catch {
            guard !Task.isCancelled, mode == .scan else { return }
            if let invitationError = error as? FolderInviteError {
                switch invitationError {
                case .invalidLink:
                    scanError = "PicTuneの撮影用QRコードを読み取ってください。"
                case .unavailable:
                    scanError = "このQRコードは期限切れか使用できません。友達に新しいコードを表示してもらってください。"
                default:
                    scanError = invitationError.localizedDescription
                }
            } else {
                scanError = "招待を確認できませんでした。通信状態を確認して、もう一度お試しください。"
            }
        }
    }

    private func resetScanner() {
        friendUid = ""
        friendName = nil
        scanError = nil
        needsCameraAccess = false
        scannerID = UUID()
    }

    @MainActor private func createCode() async {
        guard !isCreatingCode else { return }
        isCreatingCode = true
        qrCodeImage = nil
        codeError = nil
        defer { isCreatingCode = false }
        do {
            let invitation = try await createInvitation()
            guard !Task.isCancelled else { return }
            guard let image = qrCodeGenerator.generate(with: invitation.payload) else {
                codeError = "QRコードを作成できませんでした。もう一度お試しください。"
                return
            }
            qrCodeImage = image
        } catch {
            guard !Task.isCancelled else { return }
            codeError = "QRコードを作成できませんでした。通信状態を確認して、もう一度お試しください。"
        }
    }
}
