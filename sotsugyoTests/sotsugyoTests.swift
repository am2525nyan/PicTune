import XCTest
import UIKit
import PencilKit
@testable import PIcTune

@MainActor
final class sotsugyoTests: XCTestCase {
    func testPhotoWithoutMusicReachesSaveAndAllowsRetryAfterFailure() async {
        let camera = RecordingCameraManager()
        let model = PhotoPreviewViewModel()
        let image = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        }

        let saved = await model.save(image: image, stamp: nil, drawing: PKDrawing(), track: nil,
                                     cameraManager: camera, friendUid: "friend")

        XCTAssertFalse(saved)
        XCTAssertEqual(camera.attempts, 1)
        XCTAssertNil(camera.savedTrack)
        XCTAssertEqual(camera.savedFriendUID, "friend")
        XCTAssertEqual(camera.savedImage?.cgImage?.width, 999)
        XCTAssertEqual(camera.savedImage?.cgImage?.height, 1587)
        XCTAssertFalse(model.isSaving)
        XCTAssertTrue(model.isShowingError)

        _ = await model.save(image: image, stamp: nil, drawing: PKDrawing(), track: nil,
                             cameraManager: camera, friendUid: "friend")
        XCTAssertEqual(camera.attempts, 2)
        XCTAssertFalse(model.isSaving)
    }

    func testSelectedMusicWithoutPreviewURLReachesSave() async {
        let camera = RecordingCameraManager()
        let model = PhotoPreviewViewModel()
        let image = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { _ in }
        let track = Track(id: "track", name: "曲名", artist: "アーティスト", albumImages: [], previewURL: nil)

        _ = await model.save(image: image, stamp: nil, drawing: PKDrawing(), track: track,
                             cameraManager: camera, friendUid: "")

        XCTAssertEqual(camera.savedTrack?.id, "track")
        XCTAssertNil(camera.savedTrack?.previewURL)
        XCTAssertEqual(camera.attempts, 1)
        XCTAssertFalse(model.isSaving)
    }

    func testPhotoWithoutMusicDoesNotStartPlayback() {
        let model = MainContentModel()
        model.Music = []
        model.startPlay()
        XCTAssertNil(model.audioPlayer)
    }
}

private final class RecordingCameraManager: CameraManager {
    var savedImage: UIImage?
    var savedTrack: Track?
    var savedFriendUID: String?
    var attempts = 0

    @MainActor
    override func uploadPhoto(_ image: UIImage, friendUid: String, track: Track? = nil) async throws {
        attempts += 1
        savedImage = image
        savedTrack = track
        savedFriendUID = friendUid
        // Stop before Photos/network writes and exercise the retryable failure state.
        throw NSError(domain: "PhotoSaveTest", code: 1)
    }
}

@MainActor
final class MusicSearchTests: XCTestCase {
    private var defaultsDomains: [String] = []

    private func isolatedDefaults() -> UserDefaults {
        let domain = "MusicSearchTests.\(UUID().uuidString)"
        defaultsDomains.append(domain)
        return UserDefaults(suiteName: domain)!
    }

    override func tearDown() {
        for domain in defaultsDomains { UserDefaults.standard.removePersistentDomain(forName: domain) }
        defaultsDomains = []
        super.tearDown()
    }

    func testHistoryDeduplicatesPersistsAndClears() {
        let defaults = isolatedDefaults()
        let model = SearchViewModel(defaults: defaults, search: { _ in [] })
        model.remember("  Artist  ")
        model.remember("artist")
        model.remember(" \n ")
        XCTAssertEqual(model.recentSearches, ["artist"])
        for index in 0..<10 { model.remember("曲\(index)") }
        XCTAssertEqual(model.recentSearches.count, 8)
        XCTAssertEqual(model.recentSearches.first, "曲9")
        let reloaded = SearchViewModel(defaults: defaults, search: { _ in [] })
        XCTAssertEqual(reloaded.recentSearches, model.recentSearches)
        reloaded.clearHistory()
        XCTAssertTrue(SearchViewModel(defaults: defaults, search: { _ in [] }).recentSearches.isEmpty)
    }

    func testFailedSearchKeepsSelectionAndRetryReplacesResults() async {
        let chosen = Track(id: "chosen", name: "選択した曲", artist: "歌手", albumImages: [], previewURL: nil)
        var shouldFail = false
        let model = SearchViewModel(selection: chosen, defaults: isolatedDefaults(), search: { query in
            if shouldFail { throw NSError(domain: "SearchTest", code: 1) }
            return [Track(id: query, name: query, artist: "歌手", albumImages: [], previewURL: nil)]
        })
        model.searchText = "最初"
        await model.search(debounce: false)
        shouldFail = true
        model.searchText = "次の検索"
        await model.search(debounce: false)
        XCTAssertEqual(model.tracks.first?.id, "最初")
        XCTAssertEqual(model.selection?.id, "chosen")
        XCTAssertNotNil(model.searchError)
        XCTAssertFalse(model.isSearching)
        shouldFail = false
        await model.search(debounce: false)
        XCTAssertEqual(model.tracks.first?.id, "次の検索")
        XCTAssertNil(model.searchError)
        XCTAssertEqual(model.selection?.id, "chosen")
        XCTAssertTrue(model.recentSearches.isEmpty, "Typing must not fill history with partial queries")
        model.select(model.tracks[0])
        XCTAssertEqual(model.recentSearches, ["次の検索"])
        model.searchText = ""
        await model.search(debounce: false)
        XCTAssertTrue(model.tracks.isEmpty)
        XCTAssertEqual(model.selection?.id, "次の検索")
    }

    func testOlderResponseCannotOverwriteNewSearch() async {
        let firstStarted = expectation(description: "First request started")
        let secondStarted = expectation(description: "Second request started")
        var completions: [String: CheckedContinuation<[Track], Error>] = [:]
        let model = SearchViewModel(defaults: isolatedDefaults(), search: { query in
            try await withCheckedThrowingContinuation { continuation in
                completions[query] = continuation
                (query == "first" ? firstStarted : secondStarted).fulfill()
            }
        })
        model.searchText = "first"
        let first = Task { await model.search(debounce: false) }
        await fulfillment(of: [firstStarted], timeout: 2)
        model.searchText = "second"
        let second = Task { await model.search(debounce: false) }
        await fulfillment(of: [secondStarted], timeout: 2)
        let latest = Track(id: "latest", name: "最新", artist: "歌手", albumImages: [], previewURL: nil)
        completions["second"]?.resume(returning: [latest])
        await second.value
        completions["first"]?.resume(returning: [])
        await first.value
        XCTAssertEqual(model.tracks.first?.id, "latest")
        XCTAssertEqual(model.resultsQuery, "second")
        XCTAssertFalse(model.isSearching)
    }
}
