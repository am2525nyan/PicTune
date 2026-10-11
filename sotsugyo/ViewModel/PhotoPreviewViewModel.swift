import SwiftUI
import PencilKit
import Photos
import FirebaseStorage

@MainActor
class PhotoPreviewViewModel: ObservableObject {
    @Published private(set) var isSaving = false
    @Published var isShowingError = false
    @Published private(set) var errorMessage = ""
    @Published private(set) var saveMessage = ""

    func save(image: UIImage, stamp: String?, drawing: PKDrawing, track: Track?,
              cameraManager: CameraManager, friendUid: String) async -> Bool {
        guard !isSaving else { return false }
        isSaving = true
        defer { isSaving = false }

        let artwork = PhotoArtwork(image: image, stamp: stamp)
            .overlay {
                Image(uiImage: drawing.image(from: CGRect(origin: .zero, size: PhotoArtwork.size), scale: 3))
                    .resizable()
                    .frame(width: PhotoArtwork.size.width, height: PhotoArtwork.size.height)
            }
        let renderer = ImageRenderer(content: artwork)
        renderer.scale = 3
        guard let renderedImage = renderer.uiImage else {
            errorMessage = "写真を作成できませんでした。もう一度お試しください。"
            isShowingError = true
            return false
        }

        do {
            try await cameraManager.uploadPhoto(renderedImage, friendUid: friendUid, track: track)
        } catch {
            errorMessage = Self.saveErrorMessage(for: error)
            isShowingError = true
            return false
        }

        // A Photos permission failure must not turn a successful app save into a retry/duplicate.
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        if status == .authorized || status == .limited {
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: renderedImage)
                }
                saveMessage = "アプリと写真ライブラリに保存しました。"
            } catch {
                saveMessage = "アプリに保存しました。写真ライブラリへの保存はできませんでした。"
            }
        } else {
            saveMessage = "アプリに保存しました。写真ライブラリへの保存は許可されていません。"
        }
        return true
    }

    static func saveErrorMessage(for error: Error) -> String {
        // StorageError does not conform to LocalizedError. Its NSError code is
        // an enum index (e.g. unauthorized = 5), not a StorageErrorCode value.
        guard let storageError = error as? StorageError else {
            return "写真を保存できませんでした。\n\(error.localizedDescription)"
        }
        switch storageError {
        case .unauthorized:
            return "写真を保存する権限がありません。アプリの管理者にお問い合わせください。\nエラー: storage/unauthorized"
        case .unauthenticated:
            return "ログイン状態を確認できませんでした。もう一度ログインして保存してください。\nエラー: storage/unauthenticated"
        case .bucketNotFound, .projectNotFound, .bucketMismatch:
            return "写真の保存先に接続できません。アプリの管理者にお問い合わせください。\nエラー: storage/configuration"
        case .quotaExceeded:
            return "写真の保存サービスが利用上限に達しています。アプリの管理者にお問い合わせください。\nエラー: storage/quota-exceeded"
        case .retryLimitExceeded:
            return "写真の保存がタイムアウトしました。通信状況を確認して、もう一度保存してください。\nエラー: storage/retry-limit-exceeded"
        case .cancelled:
            return "写真の保存が中断されました。もう一度保存してください。\nエラー: storage/cancelled"
        default:
            return "写真を保存できませんでした。通信状況を確認して、もう一度保存してください。\nエラー: storage/upload-failed"
        }
    }
}
