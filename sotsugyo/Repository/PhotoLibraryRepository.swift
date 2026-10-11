import Foundation
import FirebaseFirestore
import FirebaseStorage

/// Firebase's document layout is confined to this boundary. Views consume models.
protocol PhotoLibraryRepository {
    func photos(userID: String, folderID: String) async throws -> [PhotoRecord]
    func coverPhoto(userID: String, folderID: String) async throws -> PhotoRecord?
    func imageData(fileName: String) async throws -> Data
    func folders(userID: String) async throws -> [PhotoFolder]
    func createFolder(userID: String, folder: PhotoFolder) async throws
    func copyPhoto(userID: String, photoID: String, to folderID: String) async throws
    func deletePhoto(userID: String, photoID: String, folderID: String) async throws
    func deleteFolder(userID: String, folderID: String) async throws
    func letter(userID: String, folderID: String) async throws -> String
    func saveLetter(userID: String, folderID: String, text: String) async throws
    func importFolder(userID: String, reference: SharedFolderReference) async throws
    func updateLibraryDate(userID: String) async throws
    func updateLastViewedDate(userID: String) async throws
    func downloadURL(fileName: String) async throws -> URL
}

extension PhotoLibraryRepository {
    func coverPhoto(userID: String, folderID: String) async throws -> PhotoRecord? {
        try await photos(userID: userID, folderID: folderID).last
    }
}

struct FirebasePhotoLibraryRepository: PhotoLibraryRepository {
    private let injectedDatabase: Firestore?
    private var database: Firestore { injectedDatabase ?? Firestore.firestore() }

    init(database: Firestore? = nil) { injectedDatabase = database }

    private func foldersReference(_ userID: String) -> CollectionReference {
        database.collection("users").document(userID).collection("folders")
    }

    func photos(userID: String, folderID: String) async throws -> [PhotoRecord] {
        let snapshot = try await foldersReference(userID).document(folderID)
            .collection("photos").order(by: "date").getDocuments()
        return snapshot.documents.compactMap { PhotoRecord(id: $0.documentID, data: $0.data()) }
    }

    func coverPhoto(userID: String, folderID: String) async throws -> PhotoRecord? {
        let snapshot = try await foldersReference(userID).document(folderID)
            .collection("photos").order(by: "date", descending: true).limit(to: 1).getDocuments()
        return snapshot.documents.first.flatMap { PhotoRecord(id: $0.documentID, data: $0.data()) }
    }

    func imageData(fileName: String) async throws -> Data {
        try await Storage.storage().reference().child("images/" + fileName)
            .data(maxSize: 100 * 1024 * 1024)
    }

    func folders(userID: String) async throws -> [PhotoFolder] {
        let snapshot = try await foldersReference(userID)
            .order(by: "date", descending: true).getDocuments()
        return snapshot.documents.map { PhotoFolder(id: $0.documentID, data: $0.data()) }
    }

    func createFolder(userID: String, folder: PhotoFolder) async throws {
        // Preserve the existing creation schema (letter is added when first saved).
        try await foldersReference(userID).document(folder.id).setData([
            "title": folder.title, "date": FieldValue.serverTimestamp()
        ])
        // A timestamp failure must not turn a completed copy/create into a retry.
        try? await updateLibraryDate(userID: userID)
    }

    func copyPhoto(userID: String, photoID: String, to folderID: String) async throws {
        let folders = foldersReference(userID)
        let source = try await folders.document(PhotoFolder.allID).collection("photos")
            .document(photoID).getDocument()
        guard let data = source.data() else { throw folderError("写真が見つかりませんでした。") }
        // Copy the complete document to retain optional and future fields.
        try await folders.document(folderID).collection("photos").document(photoID).setData(data)
    }

    func deletePhoto(userID: String, photoID: String, folderID: String) async throws {
        try await foldersReference(userID).document(folderID).collection("photos")
            .document(photoID).delete()
    }

    func deleteFolder(userID: String, folderID: String) async throws {
        guard folderID != PhotoFolder.allID else { throw folderError("このフォルダは削除できません。") }
        let folder = foldersReference(userID).document(folderID)
        // Deleting a Firestore document does not delete its subcollections.
        while true {
            let photos = try await folder.collection("photos").limit(to: 400).getDocuments()
            guard !photos.isEmpty else { break }
            let batch = database.batch()
            photos.documents.forEach { batch.deleteDocument($0.reference) }
            try await batch.commit()
        }
        try await folder.delete()
    }

    func letter(userID: String, folderID: String) async throws -> String {
        let document = try await foldersReference(userID).document(folderID).getDocument()
        guard document.exists else {
            throw NSError(domain: "PicTune.Folder", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "フォルダが見つかりませんでした。"])
        }
        return PhotoFolder(id: document.documentID, data: document.data() ?? [:]).letter
    }

    func saveLetter(userID: String, folderID: String, text: String) async throws {
        try await foldersReference(userID).document(folderID).updateData(["letter": text])
    }

    func importFolder(userID: String, reference: SharedFolderReference) async throws {
        guard SharedFolderReference(payload: reference.payload) == reference,
              reference.folderID != PhotoFolder.allID else { throw folderError("フォルダの情報が正しくありません。") }
        guard userID != reference.userID else { throw folderError("自分のフォルダは取り込めません。") }
        let source = foldersReference(reference.userID).document(reference.folderID)
        let document = try await source.getDocument()
        guard let data = document.data() else { throw folderError("共有元のフォルダが見つかりませんでした。") }
        let folder = PhotoFolder(id: reference.importedFolderID, title: data["title"] as? String ?? "名称未設定",
                                 date: nil, letter: data["letter"] as? String ?? "")
        let destination = foldersReference(userID).document(folder.id)
        let photos = try await source.collection("photos").getDocuments()
        // Stable destination IDs make a retry safe, including after a partial batch failure.
        for start in stride(from: 0, to: photos.documents.count, by: 400) {
            let batch = database.batch()
            for photo in photos.documents[start..<min(start + 400, photos.documents.count)] {
                batch.setData(photo.data(), forDocument: destination.collection("photos").document(photo.documentID))
            }
            try await batch.commit()
        }
        // Publish a new folder only after every photo is copied. Re-importing must not
        // replace a letter or title the recipient has edited.
        _ = try await database.runTransaction { transaction, errorPointer in
            do {
                if !(try transaction.getDocument(destination)).exists {
                    transaction.setData(folder.firestoreData(date: FieldValue.serverTimestamp()), forDocument: destination)
                }
                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
        // A timestamp failure must not turn a completed copy/create into a retry.
        try? await updateLibraryDate(userID: userID)
    }

    func updateLibraryDate(userID: String) async throws {
        try await foldersReference(userID).document(PhotoFolder.allID)
            .setData(["title": "all", "date": FieldValue.serverTimestamp()], merge: true)
    }

    func updateLastViewedDate(userID: String) async throws {
        try await database.collection("users").document(userID)
            .setData(["date": FieldValue.serverTimestamp()], merge: true)
    }

    private func folderError(_ message: String) -> NSError {
        NSError(domain: "PicTune.Folder", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    func downloadURL(fileName: String) async throws -> URL {
        try await Storage.storage().reference().child("images/" + fileName).downloadURL()
    }
}
