import XCTest
import FirebaseCore
import FirebaseFirestore
@testable import PIcTune

/// Local Firestore only. Start the emulator on 127.0.0.1:8089 to run these tests.
@MainActor
final class RepositoryIntegrationTests: XCTestCase {
    private var database: Firestore!
    private var repository: FirebasePhotoLibraryRepository!
    private var owner = ""
    private var recipient = ""

    override func setUp() async throws {
        var request = URLRequest(url: URL(string: "http://127.0.0.1:8089/")!)
        request.timeoutInterval = 1
        do { _ = try await URLSession.shared.data(for: request) }
        catch { throw XCTSkip("Local Firestore emulator is not running on port 8089") }
        let name = "PicTuneRepositoryIntegration"
        if FirebaseApp.app(name: name) == nil {
            let options = FirebaseOptions(googleAppID: "1:123456789:ios:abcdef", gcmSenderID: "123456789")
            options.projectID = "demo-pictune-audit"
            options.apiKey = "emulator-only"
            FirebaseApp.configure(name: name, options: options)
            let emulator = Firestore.firestore(app: FirebaseApp.app(name: name)!)
            let settings = emulator.settings
            settings.host = "127.0.0.1:8089"
            settings.isSSLEnabled = false
            settings.cacheSettings = MemoryCacheSettings()
            emulator.settings = settings
        }
        database = Firestore.firestore(app: FirebaseApp.app(name: name)!)
        repository = FirebasePhotoLibraryRepository(database: database)
        owner = "owner-\(UUID().uuidString)"
        recipient = "recipient-\(UUID().uuidString)"
    }

    private func folder(_ user: String, _ id: String) -> DocumentReference {
        database.collection("users").document(user).collection("folders").document(id)
    }

    private func seed(_ count: Int = 1) async throws -> SharedFolderReference {
        let reference = SharedFolderReference(userID: owner, folderID: "shared-folder")
        try await folder(owner, reference.folderID).setData(["title": "共有", "letter": "手紙", "date": Timestamp(date: Date())])
        for start in stride(from: 0, to: count, by: 400) {
            let batch = database.batch()
            for index in start..<min(start + 400, count) {
                batch.setData(["url": "photo-\(index).jpg", "date": Timestamp(date: Date()),
                               "id": "track-\(index)", "trackName": "楽曲", "custom": "preserved"],
                              forDocument: folder(owner, reference.folderID).collection("photos").document("photo-\(index)"))
            }
            try await batch.commit()
        }
        return reference
    }

    func testRepeatedImportKeepsPhotoIdentityMusicAndRecipientLetter() async throws {
        let reference = try await seed()
        try await folder(recipient, reference.folderID).setData(["title": "自分の既存フォルダ", "letter": "keep"])
        try await repository.importFolder(userID: recipient, reference: reference)
        let destination = folder(recipient, reference.importedFolderID)
        try await destination.updateData(["letter": "受信者が編集"])
        try await repository.importFolder(userID: recipient, reference: reference)
        let photos = try await destination.collection("photos").getDocuments()
        XCTAssertEqual(photos.documents.map(\.documentID), ["photo-0"])
        XCTAssertEqual(photos.documents.first?.data()["id"] as? String, "track-0")
        XCTAssertEqual(photos.documents.first?.data()["custom"] as? String, "preserved")
        let imported = try await destination.getDocument()
        XCTAssertEqual(imported.data()?["letter"] as? String, "受信者が編集")
        let original = try await folder(recipient, reference.folderID).getDocument()
        XCTAssertEqual(original.data()?["letter"] as? String, "keep")
    }

    func testMissingSelfAndInvalidImportsFailWithoutCreatingFolder() async throws {
        let reference = try await seed()
        let invalid = [reference, SharedFolderReference(userID: "missing", folderID: "folder"),
                       SharedFolderReference(userID: "bad/path", folderID: "folder"),
                       SharedFolderReference(userID: "other", folderID: "all")]
        for value in invalid {
            do { try await repository.importFolder(userID: owner, reference: value); XCTFail("Expected rejection") }
            catch { }
        }
        let folders = try await database.collection("users").document(owner).collection("folders").getDocuments()
        XCTAssertEqual(folders.documents.map(\.documentID), [reference.folderID])
    }

    func testImportAndDeleteCrossBatchBoundaryWithoutOrphanPhotos() async throws {
        let reference = try await seed(401)
        try await repository.importFolder(userID: recipient, reference: reference)
        let destination = folder(recipient, reference.importedFolderID)
        let imported = try await destination.collection("photos").getDocuments()
        XCTAssertEqual(imported.count, 401)
        try await repository.deleteFolder(userID: recipient, folderID: reference.importedFolderID)
        let deleted = try await destination.getDocument()
        let children = try await destination.collection("photos").getDocuments()
        let source = try await folder(owner, reference.folderID).collection("photos").getDocuments()
        XCTAssertFalse(deleted.exists)
        XCTAssertTrue(children.isEmpty)
        XCTAssertEqual(source.count, 401)
    }

    func testRetryFinishesPreexistingPartialImportWithoutDuplicatingPhotos() async throws {
        let reference = try await seed(3)
        let destination = folder(recipient, reference.importedFolderID)
        try await destination.collection("photos").document("photo-0").setData(["url": "partial.jpg"])
        try await repository.importFolder(userID: recipient, reference: reference)
        let imported = try await destination.collection("photos").getDocuments()
        XCTAssertEqual(imported.count, 3)
        let first = try await destination.collection("photos").document("photo-0").getDocument()
        XCTAssertEqual(first.data()?["url"] as? String, "photo-0.jpg")
    }

    func testCopyIsIdempotentAndMissingPhotoFails() async throws {
        try await folder(owner, "all").collection("photos").document("photo").setData(["url": "photo.jpg", "id": "music"])
        for _ in 0..<2 { try await repository.copyPhoto(userID: owner, photoID: "photo", to: "folder") }
        let photos = try await folder(owner, "folder").collection("photos").getDocuments()
        XCTAssertEqual(photos.count, 1)
        XCTAssertEqual(photos.documents.first?.data()["id"] as? String, "music")
        do { try await repository.copyPhoto(userID: owner, photoID: "missing", to: "folder"); XCTFail("Expected missing source error") }
        catch { }
    }

    func testTimestampUpdatesPreserveOtherFieldsAndCreateMissingLibrary() async throws {
        let user = database.collection("users").document(owner)
        try await user.setData(["custom": "keep"])
        try await repository.updateLastViewedDate(userID: owner)
        try await repository.updateLibraryDate(userID: owner)
        let updated = try await user.getDocument()
        let library = try await folder(owner, "all").getDocument()
        XCTAssertEqual(updated.data()?["custom"] as? String, "keep")
        XCTAssertTrue(library.exists)
        do { try await repository.deleteFolder(userID: owner, folderID: "all"); XCTFail("Cannot delete library") }
        catch { }
    }
}
