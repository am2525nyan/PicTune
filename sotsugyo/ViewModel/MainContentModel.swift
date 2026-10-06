import Foundation
import UIKit
import Combine
import FirebaseAuth
import Photos
import WidgetKit

/// Screen state is published as complete records, never as parallel arrays.
@MainActor
class MainContentModel: ObservableObject {
    @Published var isShowSheet = false
    @Published var isPresentingCamera = false
    @Published var isAnimating = false
    @Published var photos: [LibraryPhoto] = []
    @Published var folders: [PhotoFolder] = []
    @Published var folderCoverImages: [String: UIImage] = [:]
    @Published var folderDocument = PhotoFolder.allID
    @Published var userDataList = ""
    @Published private(set) var nfc = false

    private let repository: any PhotoLibraryRepository
    private let currentUserID: () -> String?
    private let widgetDefaults: UserDefaults?
    private let reloadWidgets: () -> Void
    private var photoDataCache: [String: Data] = [:]
    private var photoLoadID = UUID()
    private var folderLoadID = UUID()
    private var coverLoadIDs: [String: UUID] = [:]
    private var sessionID = UUID()

    init(repository: any PhotoLibraryRepository = FirebasePhotoLibraryRepository(),
         currentUserID: @escaping () -> String? = { Auth.auth().currentUser?.uid },
         widgetDefaults: UserDefaults? = UserDefaults(suiteName: "group.PIcTune"),
         reloadWidgets: @escaping () -> Void = { WidgetCenter.shared.reloadAllTimelines() }) {
        self.repository = repository
        self.currentUserID = currentUserID
        self.widgetDefaults = widgetDefaults
        self.reloadWidgets = reloadWidgets
    }

    func reset() {
        photoLoadID = UUID()
        folderLoadID = UUID()
        sessionID = UUID()
        nfc = false
        photos = []
        folders = []
        folderCoverImages = [:]
        coverLoadIDs = [:]
        photoDataCache = [:]
        folderDocument = PhotoFolder.allID
        userDataList = ""
        isShowSheet = false
        isPresentingCamera = false
        clearWidget()
    }

    func firstgetUrl() async throws {
        try await loadPhotos(folderID: PhotoFolder.allID)
    }

    func loadPhotos(folderID: String) async throws {
        guard let uid = currentUserID() else { reset(); return }
        let requestID = UUID()
        photoLoadID = requestID
        folderDocument = folderID
        photos = []
        userDataList = ""

        let records = try await repository.photos(userID: uid, folderID: folderID)
        var loaded: [LibraryPhoto] = []
        for record in records {
            guard isCurrentPhotoRequest(requestID, userID: uid) else { return }
            do {
                let data = try await imageData(fileName: record.fileName)
                guard let image = UIImage(data: data) else { continue }
                loaded.append(LibraryPhoto(record: record, image: image))
                // Keep the library's progressive loading without splitting record fields.
                if folderID == PhotoFolder.allID, isCurrentPhotoRequest(requestID, userID: uid) {
                    photos = loaded
                }
            } catch is CancellationError {
                return
            } catch {
                // A failed image must never take another photo's ID, date or music.
                print("写真の読み込みに失敗しました: \(record.id), \(error)")
            }
        }
        guard isCurrentPhotoRequest(requestID, userID: uid) else { return }
        photos = loaded

        if folderID == PhotoFolder.allID {
            await updateWidget(records: records, requestID: requestID, userID: uid)
            guard isCurrentPhotoRequest(requestID, userID: uid) else { return }
            try await repository.updateLibraryDate(userID: uid)
        } else {
            try await repository.updateLastViewedDate(userID: uid)
        }
    }

    private func isCurrentPhotoRequest(_ id: UUID, userID: String) -> Bool {
        photoLoadID == id && currentUserID() == userID && !Task.isCancelled
    }

    private func imageData(fileName: String) async throws -> Data {
        if let cached = photoDataCache[fileName] { return cached }
        let session = sessionID
        let data = try await repository.imageData(fileName: fileName)
        if sessionID == session { photoDataCache[fileName] = data }
        return data
    }

    private func updateWidget(records: [PhotoRecord], requestID: UUID, userID: String) async {
        let selected = Array(records.shuffled().prefix(3))
        var urls: [String] = []
        for record in selected {
            guard isCurrentPhotoRequest(requestID, userID: userID) else { return }
            do {
                let url = try await repository.downloadURL(fileName: record.fileName)
                guard isCurrentPhotoRequest(requestID, userID: userID) else { return }
                urls.append(url.absoluteString)
            } catch {
                print("ウィジェット画像の取得に失敗しました: \(error)")
            }
        }
        guard isCurrentPhotoRequest(requestID, userID: userID) else { return }
        for (index, key) in WidgetPhotoLoader.keys.enumerated() {
            if index < urls.count { widgetDefaults?.set(urls[index], forKey: key) }
            else { widgetDefaults?.removeObject(forKey: key) }
        }
        reloadWidgets()
    }

    private func clearWidget() {
        WidgetPhotoLoader.keys.forEach { widgetDefaults?.removeObject(forKey: $0) }
        reloadWidgets()
    }

    func getFolder() async throws {
        guard let uid = currentUserID() else { reset(); return }
        let requestID = UUID()
        folderLoadID = requestID
        let loaded = try await repository.folders(userID: uid)
        guard folderLoadID == requestID, currentUserID() == uid, !Task.isCancelled else { return }
        folders = loaded
        let ids = Set(loaded.map(\.id))
        folderCoverImages = folderCoverImages.filter { ids.contains($0.key) }
    }

    func makeFolder(folderName: String) async throws {
        let uid = try signedInUserID()
        let name = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw folderError("フォルダ名を入力してください。") }
        let session = sessionID
        let folder = PhotoFolder(id: UUID().uuidString, title: name, date: nil, letter: "")
        try await repository.createFolder(userID: uid, folder: folder)
        guard sessionID == session, currentUserID() == uid else { throw CancellationError() }
        folderLoadID = UUID()
        folders.removeAll { $0.id == folder.id }
        folders.insert(folder, at: min(1, folders.count))
    }

    func loadFolderCover(folderId: String) async throws {
        guard folderCoverImages[folderId] == nil, let uid = currentUserID() else { return }
        let session = sessionID
        let request = UUID()
        coverLoadIDs[folderId] = request
        guard let record = try await repository.coverPhoto(userID: uid, folderID: folderId) else { return }
        let data = try await imageData(fileName: record.fileName)
        guard sessionID == session, currentUserID() == uid, coverLoadIDs[folderId] == request,
              folders.contains(where: { $0.id == folderId }), let image = UIImage(data: data) else { return }
        folderCoverImages[folderId] = image
    }

    func appendFolder(photoDocumentID: String, to destinationFolderID: String) async throws {
        let uid = try signedInUserID()
        let session = sessionID
        try await repository.copyPhoto(userID: uid, photoID: photoDocumentID, to: destinationFolderID)
        guard sessionID == session, currentUserID() == uid else { throw CancellationError() }
        invalidateCover(folderID: destinationFolderID)
    }

    func saveLetter(_ text: String, folderID: String) async throws {
        let uid = try signedInUserID()
        let session = sessionID
        try await repository.saveLetter(userID: uid, folderID: folderID, text: text)
        guard sessionID == session, currentUserID() == uid else { throw CancellationError() }
        if folderDocument == folderID { userDataList = text }
        if let index = folders.firstIndex(where: { $0.id == folderID }) {
            let folder = folders[index]
            folders[index] = PhotoFolder(id: folder.id, title: folder.title, date: folder.date, letter: text)
        }
    }

    func loadLetter(folderID: String) async throws -> String {
        let uid = try signedInUserID()
        let session = sessionID
        let letter = try await repository.letter(userID: uid, folderID: folderID)
        guard sessionID == session, currentUserID() == uid, !Task.isCancelled else { throw CancellationError() }
        return letter
    }

    func deletePhoto(document: String, folderId: String) async throws {
        let uid = try signedInUserID()
        let session = sessionID
        try await repository.deletePhoto(userID: uid, photoID: document, folderID: folderId)
        guard sessionID == session, currentUserID() == uid else { throw CancellationError() }
        if folderDocument == folderId {
            photoLoadID = UUID()
            photos.removeAll { $0.id == document }
        }
        invalidateCover(folderID: folderId)
        if folderId == PhotoFolder.allID {
            // Invalidate URLs immediately, even if a subsequent network reload fails.
            clearWidget()
        }
    }

    func deleteFolder(id: String) async throws {
        guard id != PhotoFolder.allID, !id.isEmpty else { throw folderError("このフォルダは削除できません。") }
        let uid = try signedInUserID()
        let session = sessionID
        try await repository.deleteFolder(userID: uid, folderID: id)
        guard sessionID == session, currentUserID() == uid else { throw CancellationError() }
        folderLoadID = UUID()
        folders.removeAll { $0.id == id }
        invalidateCover(folderID: id)
        if folderDocument == id {
            photoLoadID = UUID()
            folderDocument = PhotoFolder.allID
            photos = []
            userDataList = ""
        }
    }

    func getNFCData(NFCUid: String, NFCfolderid: String) async throws {
        guard !nfc else { throw folderError("フォルダを読み込み中です。完了してからもう一度お試しください。") }
        let uid = try signedInUserID()
        let session = sessionID
        nfc = true
        defer { if sessionID == session { nfc = false } }
        let reference = SharedFolderReference(userID: NFCUid, folderID: NFCfolderid)
        try await repository.importFolder(userID: uid, reference: reference)
        guard sessionID == session, currentUserID() == uid else { throw CancellationError() }
        try await getFolder()
        guard sessionID == session, currentUserID() == uid else { throw CancellationError() }
        invalidateCover(folderID: reference.importedFolderID)
        try? await loadFolderCover(folderId: reference.importedFolderID)
    }

    private func invalidateCover(folderID: String) {
        coverLoadIDs[folderID] = UUID()
        folderCoverImages.removeValue(forKey: folderID)
    }

    func downloadFile(photo: LibraryPhoto) {
        // The selected image and its document metadata are one immutable value.
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: photo.image)
        } completionHandler: { _, error in
            if let error { print("写真の保存に失敗しました: \(error)") }
        }
    }

    private func signedInUserID() throws -> String {
        guard let uid = currentUserID() else {
            throw folderError("ログイン状態を確認して、もう一度お試しください。")
        }
        return uid
    }

    private func folderError(_ message: String) -> NSError {
        NSError(domain: "PicTune.Folder", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
