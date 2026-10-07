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

    func testExistingAccountBootstrapPreservesProfileLibraryAndLegacyPhotos() async throws {
        let user = database.collection("users").document(owner)
        let profile = user.collection("personal").document("info")
        let all = folder(owner, "all")
        let savedDate = Timestamp(date: Date(timeIntervalSince1970: 1_700_000_000))
        let profileData: [String: Any] = ["uid": owner, "name": "編集済み", "email": "saved@example.com", "custom": "keep"]
        let libraryData: [String: Any] = ["title": "all", "date": savedDate, "letter": "既存の手紙", "custom": "keep"]
        try await profile.setData(profileData)
        try await all.setData(libraryData)
        try await all.collection("photos").document("legacy-photo").setData([
            "url": "existing.jpg", "date": savedDate, "id": "old-spotify-id", "trackName": "昔の曲"])

        for _ in 0..<2 {
            try await UserAccountBootstrap.save(userID: owner,
                profile: UserProfile(name: "認証サービスの名前", email: "new@example.com"), database: database)
        }
        let savedProfile = try await profile.getDocument()
        let savedLibrary = try await all.getDocument()
        XCTAssertTrue(NSDictionary(dictionary: savedProfile.data() ?? [:]).isEqual(to: profileData))
        XCTAssertTrue(NSDictionary(dictionary: savedLibrary.data() ?? [:]).isEqual(to: libraryData))
        let photos = try await repository.photos(userID: owner, folderID: "all")
        XCTAssertEqual(photos.map(\.id), ["legacy-photo"])
        XCTAssertEqual(photos.first?.fileName, "existing.jpg")
        XCTAssertEqual(photos.first?.music?.provider, .spotify)
        XCTAssertEqual(photos.first?.music?.trackId, "old-spotify-id")
    }

    func testIncompleteExistingAccountIsRepairedWithoutReplacingNameOrPhotos() async throws {
        let profile = database.collection("users").document(owner).collection("personal").document("info")
        try await profile.setData(["name": "", "custom": "keep"])
        // A missing parent document must not remove its existing photos subcollection.
        try await folder(owner, "all").collection("photos").document("existing").setData([
            "url": "existing.jpg", "date": Timestamp(date: Date())])
        try await UserAccountBootstrap.save(userID: owner,
            profile: UserProfile(name: "認証サービスの名前", email: "saved@example.com"), database: database)
        let repaired = try await profile.getDocument()
        XCTAssertEqual(repaired.data()?["name"] as? String, "")
        XCTAssertEqual(repaired.data()?["email"] as? String, "saved@example.com")
        XCTAssertEqual(repaired.data()?["uid"] as? String, owner)
        XCTAssertEqual(repaired.data()?["custom"] as? String, "keep")
        let folders = try await repository.folders(userID: owner)
        let photos = try await repository.photos(userID: owner, folderID: "all")
        XCTAssertEqual(folders.map(\.id), ["all"])
        XCTAssertEqual(photos.map(\.id), ["existing"])
    }

    func testLegacyFolderReadEditAndCopyKeepExistingPhotoMusicAndUnknownFields() async throws {
        let oldFolder = folder(owner, "old-import-id")
        let date = Timestamp(date: Date(timeIntervalSince1970: 1_700_000_000))
        try await oldFolder.setData(["title": "以前のフォルダ", "letter": "以前の手紙", "date": date])
        let data: [String: Any] = ["url": "old.jpg", "date": date, "livephotoUrl": "old.mov",
            "id": "spotify-id", "artistName": "歌手", "trackName": "曲", "imageName": "https://example.com/art.jpg",
            "previewUrl": "https://example.com/preview.mp3", "custom": "keep"]
        try await oldFolder.collection("photos").document("old-random-copy-id").setData(data)
        try await folder(owner, "all").collection("photos").document("original-id").setData(data)
        let photos = try await repository.photos(userID: owner, folderID: "old-import-id")
        XCTAssertEqual(photos.map(\.id), ["old-random-copy-id"])
        XCTAssertEqual(photos.first?.music?.trackId, "spotify-id")
        XCTAssertEqual(photos.first?.music?.provider, .spotify)
        XCTAssertEqual(photos.first?.livePhotoFileName, "old.mov")
        let oldLetter = try await repository.letter(userID: owner, folderID: "old-import-id")
        XCTAssertEqual(oldLetter, "以前の手紙")
        try await repository.saveLetter(userID: owner, folderID: "old-import-id", text: "編集した手紙")
        try await repository.copyPhoto(userID: owner, photoID: "original-id", to: "another-folder")
        for reference in [oldFolder.collection("photos").document("old-random-copy-id"),
                          folder(owner, "another-folder").collection("photos").document("original-id")] {
            let saved = try await reference.getDocument()
            XCTAssertTrue(NSDictionary(dictionary: saved.data() ?? [:]).isEqual(to: data))
        }
        let edited = try await oldFolder.getDocument()
        XCTAssertEqual(edited.data()?["letter"] as? String, "編集した手紙")
        XCTAssertEqual(edited.data()?["title"] as? String, "以前のフォルダ")
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
