import XCTest
import UIKit
import PencilKit
@testable import PIcTune

@MainActor
final class LibraryRegressionTests: XCTestCase {
    func testSavedArtworkPreservesFullFrameResolutionAndAddsDrawingAtTheSameCoordinates() throws {
        let image = UITestFixtures.image()
        let blank = SavedPhotoArtwork.render(image: image, stamp: nil, drawing: PKDrawing())
        XCTAssertEqual(blank.cgImage?.width, image.cgImage?.width)
        XCTAssertEqual(blank.cgImage?.height, image.cgImage?.height)
        XCTAssertEqual(pixel(blank, x: 5, y: 5), pixel(image, x: 5, y: 5))
        XCTAssertEqual(pixel(blank, x: 50, y: 200), pixel(image, x: 50, y: 200))
        let points = [CGPoint(x: 80, y: 470), CGPoint(x: 250, y: 470)].enumerated().map { index, point in
            PKStrokePoint(location: point, timeOffset: Double(index) * 0.1, size: CGSize(width: 12, height: 12),
                          opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        let drawing = PKDrawing(strokes: [PKStroke(ink: PKInk(.pen, color: .red),
            path: PKStrokePath(controlPoints: points, creationDate: Date()))])
        let edited = SavedPhotoArtwork.render(image: image, stamp: nil, drawing: drawing)
        XCTAssertNotEqual(pixel(edited, x: 160, y: 470), pixel(image, x: 160, y: 470))
        XCTAssertEqual(pixel(edited, x: 50, y: 200), pixel(image, x: 50, y: 200))
        let stamped = SavedPhotoArtwork.render(image: image, stamp: "1", drawing: PKDrawing())
        XCTAssertNotEqual(stamped.pngData(), blank.pngData())
        let wide = UIGraphicsImageRenderer(size: CGSize(width: 800, height: 600)).image { _ in }
        XCTAssertEqual(SavedPhotoArtwork.canvasSize(for: wide).height, 249.75)
        let wideResult = SavedPhotoArtwork.render(image: wide, stamp: nil, drawing: PKDrawing())
        XCTAssertEqual(wideResult.cgImage?.width, wide.cgImage?.width)
        XCTAssertEqual(wideResult.cgImage?.height, wide.cgImage?.height)
    }

    func testPhotoEditUpdatesCopiesOtherTabAndWidgetWithoutChangingDateOrMusic() async throws {
        let repository = LibraryRegressionRepository()
        let music = FirebaseMusic(id: "music", artistName: "歌手", imageName: "", trackName: "曲", trackId: "track", previewURL: "")
        let record = PhotoRecord(id: "photo", fileName: "original.jpg", date: Date(timeIntervalSince1970: 100), music: music, livePhotoFileName: "live.mov")
        repository.records = [record]
        repository.editAction = { photo, data in
            XCTAssertEqual(photo.fileName, "original.jpg")
            XCTAssertNotNil(UIImage(data: data))
            repository.records = [record.replacingImage(fileName: "edited.jpg")]
            return "edited.jpg"
        }
        let domain = "PhotoEdit.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = MainContentModel(repository: repository, currentUserID: { "user" }, widgetDefaults: defaults, widgetDirectory: directory, reloadWidgets: {})
        let otherTab = MainContentModel(repository: repository, currentUserID: { "user" }, widgetDefaults: nil, reloadWidgets: {})
        let otherUser = MainContentModel(repository: repository, currentUserID: { "different-user" }, widgetDefaults: nil, reloadWidgets: {})
        let image = UITestFixtures.image()
        let photo = LibraryPhoto(record: record, image: image)
        model.photos = [photo]
        otherTab.photos = [LibraryPhoto(record: PhotoRecord(id: "legacy-copy", fileName: record.fileName, date: record.date, music: music, livePhotoFileName: "live.mov"), image: image)]
        otherUser.photos = [photo]
        let result = try await model.savePhotoEdits(photo: photo, image: UITestFixtures.image(true), folderID: "all")
        XCTAssertEqual(result.record.fileName, "edited.jpg")
        XCTAssertEqual(model.photos.first?.record.fileName, "edited.jpg")
        XCTAssertEqual(otherTab.photos.first?.id, "legacy-copy")
        XCTAssertEqual(otherTab.photos.first?.record.fileName, "edited.jpg")
        XCTAssertEqual(otherUser.photos.first?.record.fileName, "original.jpg")
        XCTAssertEqual(result.record.id, record.id)
        XCTAssertEqual(result.record.date, record.date)
        XCTAssertEqual(result.record.music?.trackId, "track")
        XCTAssertEqual(result.record.livePhotoFileName, "live.mov")
        let widgetImage = try UIImage(data: Data(contentsOf: directory.appendingPathComponent("widget-first.jpg")))
        XCTAssertEqual(widgetImage?.pngData(), result.image.pngData())
    }

    func testPhotoLoadingDuringAnEditKeepsTheEditAndTheRemainingPhotos() async throws {
        let repository = LibraryRegressionRepository()
        let first = PhotoRecord(id: "first", fileName: "first.jpg", date: nil, music: nil, livePhotoFileName: "")
        let second = PhotoRecord(id: "second", fileName: "second.jpg", date: nil, music: nil, livePhotoFileName: "")
        repository.records = [first, second]
        let started = expectation(description: "Original image started loading")
        var continuation: CheckedContinuation<Data, Error>?
        var requests = 0
        let originalImage = UITestFixtures.image()
        repository.loadImage = {
            requests += 1
            if requests == 1 { return try await withCheckedThrowingContinuation { continuation = $0; started.fulfill() } }
            return originalImage.pngData()!
        }
        let model = MainContentModel(repository: repository, currentUserID: { "user" }, widgetDefaults: nil, reloadWidgets: {})
        let loading = Task { try await model.loadPhotos(folderID: "all") }
        await fulfillment(of: [started], timeout: 2)
        let result = try await model.savePhotoEdits(photo: LibraryPhoto(record: first, image: originalImage), image: UITestFixtures.image(true), folderID: "all")
        continuation?.resume(returning: originalImage.pngData()!)
        try await loading.value
        XCTAssertEqual(model.photos.map(\.id), ["first", "second"])
        XCTAssertEqual(model.photos.first?.record.fileName, result.record.fileName)
        XCTAssertEqual(model.photos.first?.image.pngData(), result.image.pngData())
        XCTAssertEqual(model.photos.last?.record.fileName, "second.jpg")
    }

    func testPhotoEditFailureAndSignedOutStateKeepTheOriginal() async throws {
        let repository = LibraryRegressionRepository()
        repository.editAction = { _, _ in throw URLError(.notConnectedToInternet) }
        var uid: String? = "user"
        let model = MainContentModel(repository: repository, currentUserID: { uid }, widgetDefaults: nil, reloadWidgets: {})
        let photo = LibraryPhoto(record: PhotoRecord(id: "photo", fileName: "original.jpg", date: nil, music: nil, livePhotoFileName: ""), image: UITestFixtures.image())
        model.photos = [photo]
        do { _ = try await model.savePhotoEdits(photo: photo, image: photo.image, folderID: "folder"); XCTFail("Expected offline error") } catch { }
        XCTAssertEqual(model.photos.first?.record.fileName, "original.jpg")
        uid = nil
        do { _ = try await model.savePhotoEdits(photo: photo, image: photo.image, folderID: "folder"); XCTFail("Expected signed out") } catch { }
        XCTAssertEqual(model.photos.first?.record.fileName, "original.jpg")
    }

    func testOldSessionPhotoEditCannotRestorePrivatePhotos() async throws {
        let repository = LibraryRegressionRepository()
        let started = expectation(description: "Edit started")
        var continuation: CheckedContinuation<String, Error>?
        repository.editAction = { _, _ in try await withCheckedThrowingContinuation { continuation = $0; started.fulfill() } }
        let model = MainContentModel(repository: repository, currentUserID: { "user" }, widgetDefaults: nil, reloadWidgets: {})
        let photo = LibraryPhoto(record: PhotoRecord(id: "photo", fileName: "original.jpg", date: nil, music: nil, livePhotoFileName: ""), image: UITestFixtures.image())
        model.photos = [photo]
        let saving = Task { try await model.savePhotoEdits(photo: photo, image: photo.image, folderID: "all") }
        await fulfillment(of: [started], timeout: 2)
        model.reset()
        continuation?.resume(returning: "edited.jpg")
        do { _ = try await saving.value; XCTFail("Old session must be discarded") } catch is CancellationError { }
        XCTAssertTrue(model.photos.isEmpty)
    }

    private func pixel(_ image: UIImage, x: Int, y: Int) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 4)
        let context = CGContext(data: &bytes, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.translateBy(x: -CGFloat(x) * image.scale, y: CGFloat(y) * image.scale + 1 - CGFloat(image.cgImage!.height))
        context.draw(image.cgImage!, in: CGRect(x: 0, y: 0, width: image.cgImage!.width, height: image.cgImage!.height))
        return bytes
    }

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

    func testWidgetSupportsOnePhotoAndClearsStalePathsAfterEmptyReloadAndLogout() async throws {
        let domain = "LibraryRegression.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        let repository = LibraryRegressionRepository()
        repository.records = [PhotoRecord(id: "photo", fileName: "photo.jpg", date: nil, music: nil, livePhotoFileName: "")]
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        var reloads = 0
        let model = MainContentModel(repository: repository, currentUserID: { "user" }, widgetDefaults: defaults, widgetDirectory: directory, reloadWidgets: { reloads += 1 })
        WidgetPhotoLoader.keys.forEach { defaults.set("https://old.example.com/photo.jpg", forKey: $0) }
        try await model.firstgetUrl()
        XCTAssertEqual(defaults.string(forKey: "first"), directory.appendingPathComponent("widget-first.jpg").path)
        let images = await WidgetPhotoLoader.loadImages(defaults: defaults, directory: directory)
        XCTAssertEqual(images.count, 1)
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
    var editAction: ((PhotoRecord, Data) async throws -> String)?
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
    func savePhotoEdits(userID: String, folderID: String, photo: PhotoRecord, imageData: Data) async throws -> String {
        try await editAction?(photo, imageData) ?? "edited.jpg"
    }
    func downloadURL(fileName: String) async throws -> URL { URL(string: "https://example.com/\(fileName)")! }
}
