import XCTest
import UIKit
@testable import PIcTune

@MainActor
final class LibraryRegressionTests: XCTestCase {
    func testOldSessionDeletionCannotTriggerNewSessionReload() async throws {
        let repository = LibraryRegressionRepository()
        let started = expectation(description: "Deletion started")
        var continuation: CheckedContinuation<Void, Error>?
        repository.deleteAction = { try await withCheckedThrowingContinuation { continuation = $0; started.fulfill() } }
        let model = MainContentModel(repository: repository, currentUserID: { "user" }, widgetDefaults: nil, reloadWidgets: {})
        let deleting = Task { try await model.deletePhoto(document: "photo", folderId: "old-folder") }
        await fulfillment(of: [started], timeout: 2)
        model.reset()
        model.folderDocument = "new-folder"
        continuation?.resume()
        do { try await deleting.value; XCTFail("Old caller must not continue reloading") } catch is CancellationError { }
        XCTAssertEqual(model.folderDocument, "new-folder")
    }

    func testLateCoverCannotRestoreADeletedPhoto() async throws {
        let repository = LibraryRegressionRepository()
        repository.records = [PhotoRecord(id: "deleted", fileName: "deleted.jpg", date: nil, music: nil, livePhotoFileName: "")]
        let started = expectation(description: "Image requested")
        var continuation: CheckedContinuation<Data, Error>?
        repository.loadImage = { try await withCheckedThrowingContinuation { continuation = $0; started.fulfill() } }
        let model = MainContentModel(repository: repository, currentUserID: { "user" }, widgetDefaults: nil, reloadWidgets: {})
        model.folders = [PhotoFolder(id: "folder", title: "folder", date: nil, letter: "")]
        let loading = Task { try await model.loadFolderCover(folderId: "folder") }
        await fulfillment(of: [started], timeout: 2)
        try await model.deletePhoto(document: "deleted", folderId: "folder")
        continuation?.resume(returning: UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { _ in }.pngData()!)
        try await loading.value
        XCTAssertNil(model.folderCoverImages["folder"])
    }

    func testWidgetSupportsOnePhotoAndClearsStaleURLsAfterEmptyReloadAndLogout() async throws {
        let domain = "LibraryRegression.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        let repository = LibraryRegressionRepository()
        repository.records = [PhotoRecord(id: "photo", fileName: "photo.jpg", date: nil, music: nil, livePhotoFileName: "")]
        var reloads = 0
        let model = MainContentModel(repository: repository, currentUserID: { "user" }, widgetDefaults: defaults, reloadWidgets: { reloads += 1 })
        WidgetPhotoLoader.keys.forEach { defaults.set("https://old.example.com/photo.jpg", forKey: $0) }
        try await model.firstgetUrl()
        XCTAssertEqual(defaults.string(forKey: "first"), "https://example.com/photo.jpg")
        XCTAssertNil(defaults.string(forKey: "second"))
        repository.records = []
        try await model.firstgetUrl()
        XCTAssertNil(defaults.string(forKey: "first"))
        defaults.set("private", forKey: "first")
        model.isShowSheet = true
        model.isPresentingCamera = true
        model.reset()
        XCTAssertNil(defaults.string(forKey: "first"))
        XCTAssertFalse(model.isShowSheet)
        XCTAssertFalse(model.isPresentingCamera)
        XCTAssertEqual(reloads, 3)
    }

    func testSignedOutMutationsThrowInsteadOfReportingSuccess() async {
        let model = MainContentModel(repository: LibraryRegressionRepository(), currentUserID: { nil }, widgetDefaults: nil, reloadWidgets: {})
        do { try await model.appendFolder(photoDocumentID: "photo", to: "folder"); XCTFail("Expected signed out") } catch { }
        do { try await model.deletePhoto(document: "photo", folderId: "all"); XCTFail("Expected signed out") } catch { }
        do { try await model.makeFolder(folderName: "folder"); XCTFail("Expected signed out") } catch { }
    }

    func testLateLetterDoesNotEscapeAnOldSession() async throws {
        let repository = LibraryRegressionRepository()
        let started = expectation(description: "Letter started")
        var continuation: CheckedContinuation<String, Error>?
        repository.loadLetter = { try await withCheckedThrowingContinuation { continuation = $0; started.fulfill() } }
        let model = MainContentModel(repository: repository, currentUserID: { "user" }, widgetDefaults: nil, reloadWidgets: {})
        let loading = Task { try await model.loadLetter(folderID: "folder") }
        await fulfillment(of: [started], timeout: 2)
        model.reset()
        continuation?.resume(returning: "private letter")
        do { _ = try await loading.value; XCTFail("Old session must be discarded") } catch is CancellationError { }
    }

    func testCreateRacingWithReloadDoesNotDuplicateFolder() async throws {
        let repository = LibraryRegressionRepository()
        let started = expectation(description: "Create started")
        var continuation: CheckedContinuation<Void, Error>?
        repository.create = { folder in
            repository.folderRecords = [folder]
            try await withCheckedThrowingContinuation { continuation = $0; started.fulfill() }
        }
        let model = MainContentModel(repository: repository, currentUserID: { "user" }, widgetDefaults: nil, reloadWidgets: {})
        let creating = Task { try await model.makeFolder(folderName: " folder ") }
        await fulfillment(of: [started], timeout: 2)
        try await model.getFolder()
        continuation?.resume()
        try await creating.value
        XCTAssertEqual(model.folders.count, 1)
        XCTAssertEqual(model.folders.first?.title, "folder")
    }

    func testNFCBusyFailsAndResetDoesNotLetOldCompletionClearNewImport() async throws {
        let repository = LibraryRegressionRepository()
        let firstStarted = expectation(description: "First started")
        let secondStarted = expectation(description: "Second started")
        var completions: [CheckedContinuation<Void, Error>] = []
        repository.importAction = {
            try await withCheckedThrowingContinuation { continuation in
                completions.append(continuation)
                (completions.count == 1 ? firstStarted : secondStarted).fulfill()
            }
        }
        let model = MainContentModel(repository: repository, currentUserID: { "user" }, widgetDefaults: nil, reloadWidgets: {})
        let first = Task { try await model.getNFCData(NFCUid: "friend", NFCfolderid: "folder") }
        await fulfillment(of: [firstStarted], timeout: 2)
        do { try await model.getNFCData(NFCUid: "friend", NFCfolderid: "folder"); XCTFail("Expected busy") } catch { }
        model.reset()
        let second = Task { try await model.getNFCData(NFCUid: "friend", NFCfolderid: "folder") }
        await fulfillment(of: [secondStarted], timeout: 2)
        completions[0].resume()
        do { try await first.value; XCTFail("Expected old session cancellation") } catch is CancellationError { }
        XCTAssertTrue(model.nfc)
        completions[1].resume()
        try await second.value
        XCTAssertFalse(model.nfc)
    }

    func testImportIdentityIncludesOwnerAndDoesNotReuseSourceFolderID() {
        let first = SharedFolderReference(userID: "first", folderID: "folder")
        let second = SharedFolderReference(userID: "second", folderID: "folder")
        XCTAssertNotEqual(first.importedFolderID, second.importedFolderID)
        XCTAssertNotEqual(first.importedFolderID, first.folderID)
        XCTAssertEqual(first.importedFolderID, SharedFolderReference(userID: "first", folderID: "folder").importedFolderID)
    }
}

@MainActor
private final class LibraryRegressionRepository: PhotoLibraryRepository {
    var records: [PhotoRecord] = []
    var folderRecords: [PhotoFolder] = []
    var loadLetter: (() async throws -> String)?
    var create: ((PhotoFolder) async throws -> Void)?
    var importAction: (() async throws -> Void)?
    var loadImage: (() async throws -> Data)?
    var deleteAction: (() async throws -> Void)?
    func photos(userID: String, folderID: String) async throws -> [PhotoRecord] { records }
    func folders(userID: String) async throws -> [PhotoFolder] { folderRecords }
    func imageData(fileName: String) async throws -> Data {
        if let loadImage { return try await loadImage() }
        return UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { _ in }.pngData()!
    }
    func createFolder(userID: String, folder: PhotoFolder) async throws { try await create?(folder) }
    func copyPhoto(userID: String, photoID: String, to folderID: String) async throws { }
    func deletePhoto(userID: String, photoID: String, folderID: String) async throws { try await deleteAction?() }
    func deleteFolder(userID: String, folderID: String) async throws { }
    func letter(userID: String, folderID: String) async throws -> String { try await loadLetter?() ?? "" }
    func saveLetter(userID: String, folderID: String, text: String) async throws { }
    func importFolder(userID: String, reference: SharedFolderReference) async throws { try await importAction?() }
    func updateLibraryDate(userID: String) async throws { }
    func updateLastViewedDate(userID: String) async throws { }
    func downloadURL(fileName: String) async throws -> URL { URL(string: "https://example.com/\(fileName)")! }
}
