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

    func testPhotoWithoutMusicDoesNotDecodeAsMusic() {
        XCTAssertNil(FirebaseMusic.from(documentID: "photo", data: ["url": "photo.jpg"]))
    }
}

@MainActor
final class AppleMusicMigrationTests: XCTestCase {
    func testAppleMusicRoundTripPreservesProviderLinkAndRegion() throws {
        let track = Track(id: "123", name: "曲名", artist: "歌手", albumImages: ["https://example.com/art.jpg"],
                          previewURL: nil, musicURL: "https://music.apple.com/jp/song/123", storefront: "jp", isrc: "TEST123")
        let restored = try XCTUnwrap(FirebaseMusic.from(documentID: "shared-photo", data: track.firestoreData))
        XCTAssertEqual(restored.id, "shared-photo")
        XCTAssertEqual(restored.trackId, "123")
        XCTAssertEqual(restored.provider, .appleMusic)
        XCTAssertEqual(restored.track.serviceURL, track.serviceURL)
        XCTAssertEqual(restored.storefront, "jp")
        XCTAssertEqual(restored.isrc, "TEST123")
        XCTAssertEqual(restored.previewURL, "")
    }

    func testLegacyTrackStaysSpotifyAndUnknownProviderIsNotReinterpreted() throws {
        var data: [String: Any] = ["id": "spotifyID", "trackName": "旧曲", "previewUrl": "https://example.com/preview.mp3"]
        let old = try XCTUnwrap(FirebaseMusic.from(documentID: "old-photo", data: data))
        XCTAssertEqual(old.provider, .spotify)
        XCTAssertEqual(old.track.serviceURL?.absoluteString, "https://open.spotify.com/track/spotifyID")
        data["musicProvider"] = "futureService"
        XCTAssertEqual(FirebaseMusic.from(documentID: "old-photo", data: data)?.provider, .unknown)
    }

    func testServiceLinkRejectsUnrelatedHost() {
        let track = Track(id: "123", name: "曲", artist: "歌手", albumImages: [], previewURL: nil,
                          musicURL: "https://example.com/redirect")
        XCTAssertNil(track.serviceURL)
    }

    func testCatalogSearchUsesDeveloperTokenAndKeepsSongsWithoutPreviews() async throws {
        let response = Data(#"{"results":{"songs":{"data":[{"id":"123","attributes":{"name":"曲名","artistName":"歌手","url":"https://music.apple.com/jp/song/123","artwork":{"url":"https://example.com/{w}x{h}.jpg"},"previews":[]}}]}}}"#.utf8)
        let api = AppleMusicAPI(authorize: { .authorized }, developerToken: { "test-token" }, countryCode: { "jp" }, transport: { request in
            XCTAssertEqual(request.url?.path, "/v1/catalog/jp/search")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
            XCTAssertNil(request.value(forHTTPHeaderField: "Music-User-Token"))
            XCTAssertEqual(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first?.value, "曲 & artist")
            return (response, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        })
        let tracks = try await api.searchTracks(query: " 曲 & artist ")
        XCTAssertEqual(tracks.count, 1)
        XCTAssertNil(tracks.first?.previewURL)
        XCTAssertEqual(tracks.first?.albumImages, ["https://example.com/300x300.jpg"])
        XCTAssertEqual(tracks.first?.provider, .appleMusic)
        XCTAssertEqual(tracks.first?.storefront, "jp")
    }

    func testDeniedPermissionNeverRequestsTokenOrNetwork() async {
        let api = AppleMusicAPI(authorize: { .denied }, developerToken: { XCTFail("Must not request token"); return "" },
                                countryCode: { "jp" }, transport: { _ in XCTFail("Must not access network"); throw AppleMusicError.invalidResponse })
        do { _ = try await api.searchTracks(query: "song"); XCTFail("Expected permission error") }
        catch { XCTAssertEqual((error as? AppleMusicError)?.errorDescription, AppleMusicError.permissionDenied.errorDescription) }
    }

    func testEmptyResultsAndRateLimitAreDifferentStates() async throws {
        var status = 200
        let api = AppleMusicAPI(authorize: { .authorized }, developerToken: { "token" }, countryCode: { "jp" }, transport: { request in
            (Data(#"{"results":{}}"#.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
        })
        let tracks = try await api.searchTracks(query: "nothing")
        XCTAssertTrue(tracks.isEmpty)
        status = 429
        do { _ = try await api.searchTracks(query: "song"); XCTFail("Expected rate limit") }
        catch { XCTAssertEqual((error as? AppleMusicError)?.errorDescription, AppleMusicError.rateLimited.errorDescription) }
    }

    func testRefreshUsesListenerStorefrontAndDoesNotFallbackToOldURL() async {
        let track = Track(id: "123", name: "曲", artist: "歌手", albumImages: [],
                          previewURL: "https://example.com/stale.mp3", storefront: "us")
        let api = AppleMusicAPI(authorize: { .authorized }, developerToken: { "token" }, countryCode: { "jp" }, transport: { request in
            XCTAssertEqual(request.url?.path, "/v1/catalog/jp/songs/123")
            return (Data(), HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!)
        })
        do { _ = try await api.refreshTrack(track); XCTFail("Expected unavailable") }
        catch { XCTAssertEqual((error as? AppleMusicError)?.errorDescription, AppleMusicError.unavailable.errorDescription) }
    }

    func testStoppedPreviewIgnoresLateResolution() async {
        let started = expectation(description: "Resolution started")
        var continuation: CheckedContinuation<Track, Error>?
        let player = MusicPreviewPlayer(resolveTrack: { _ in
            try await withCheckedThrowingContinuation { continuation = $0; started.fulfill() }
        })
        let track = Track(id: "123", name: "曲", artist: "歌手", albumImages: [], previewURL: nil)
        player.toggle(track)
        await fulfillment(of: [started], timeout: 2)
        player.stop()
        continuation?.resume(returning: track)
        await Task.yield()
        XCTAssertEqual(player.state, .idle)
        XCTAssertNil(player.audioPlayer)
        XCTAssertNil(player.resolvedTrack)
    }

    func testMissingPreviewReturnsToIdleWithExplanation() async {
        let resolved = expectation(description: "Resolved")
        let player = MusicPreviewPlayer(resolveTrack: { track in resolved.fulfill(); return track })
        player.toggle(Track(id: "123", name: "曲", artist: "歌手", albumImages: [], previewURL: nil))
        await fulfillment(of: [resolved], timeout: 2)
        XCTAssertEqual(player.state, .idle)
        XCTAssertEqual(player.message, "この曲には試聴音源がありません。")
        XCTAssertNil(player.audioPlayer)
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
