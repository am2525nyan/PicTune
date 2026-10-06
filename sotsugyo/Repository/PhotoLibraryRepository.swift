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
    private var database: Firestore { Firestore.firestore() }

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
        guard let data = source.data() else { return }
        // Copy the complete document to retain optional and future fields.
        try await folders.document(folderID).collection("photos").document().setData(data)
    }

    func deletePhoto(userID: String, photoID: String, folderID: String) async throws {
        try await foldersReference(userID).document(folderID).collection("photos")
            .document(photoID).delete()
    }

    func deleteFolder(userID: String, folderID: String) async throws {
        try await foldersReference(userID).document(folderID).delete()
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
        let source = foldersReference(reference.userID).document(reference.folderID)
        let document = try await source.getDocument()
        let data = document.data() ?? [:]
        let folder = PhotoFolder(id: reference.folderID, title: data["title"] as? String ?? "デフォルトのタイトル",
                                 date: nil, letter: data["letter"] as? String ?? "")
        let destination = foldersReference(userID).document(reference.folderID)
        try await destination.setData(folder.firestoreData(date: FieldValue.serverTimestamp()))
        let photos = try await source.collection("photos").order(by: "date").getDocuments()
        for photo in photos.documents {
            // The copied document already contains its music. No lookup with a stale source ID.
            _ = try await destination.collection("photos").addDocument(data: photo.data())
        }
        // A timestamp failure must not turn a completed copy/create into a retry.
        try? await updateLibraryDate(userID: userID)
    }

    func updateLibraryDate(userID: String) async throws {
        try await foldersReference(userID).document(PhotoFolder.allID)
            .updateData(["title": "all", "date": FieldValue.serverTimestamp()])
    }

    func updateLastViewedDate(userID: String) async throws {
        try await database.collection("users").document(userID)
            .setData(["date": FieldValue.serverTimestamp()])
    }

    func downloadURL(fileName: String) async throws -> URL {
        try await Storage.storage().reference().child("images/" + fileName).downloadURL()
    }
}
