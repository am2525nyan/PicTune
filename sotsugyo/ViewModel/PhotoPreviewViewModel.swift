import SwiftUI
import PencilKit
import Photos

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
            errorMessage = "通信状況を確認して、もう一度保存してください。\n\(error.localizedDescription)"
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
}
