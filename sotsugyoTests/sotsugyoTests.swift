import XCTest
import UIKit
import PencilKit
@testable import PIcTune

@MainActor
final class sotsugyoTests: XCTestCase {
    func testInvitationLinksAcceptOnlyExactTrustedRoutes() {
        let token = String(repeating: "a", count: 64)
        let link = FolderInviteLink(token: token)
        XCTAssertEqual(FolderInviteLink(url: link.url), link)
        XCTAssertEqual(FolderInviteLink(url: URL(string: "pictune://invite/\(token)")!), link)
        for value in ["https://evil.example/invite/\(token)", "http://sotugyou-7ea16.web.app/invite/\(token)",
                      "https://sotugyou-7ea16.web.app/invite/short", "https://sotugyou-7ea16.web.app/invite/\(token)?owner=other",
                      "https://sotugyou-7ea16.web.app/invite/\(token)/extra", "https://user@sotugyou-7ea16.web.app/invite/\(token)",
                      "pictune://invite/\(token)#other"] {
            XCTAssertNil(FolderInviteLink(url: URL(string: value)!), value)
        }
        XCTAssertNotEqual(FolderInviteLink.make().token, FolderInviteLink.make().token)
    }

    func testPendingInvitationSurvivesLoginAndRelaunch() {
        let defaults = UserDefaults(suiteName: "PicTune.Invitation.UnitTests")!
        defaults.removePersistentDomain(forName: "PicTune.Invitation.UnitTests")
        defer { defaults.removePersistentDomain(forName: "PicTune.Invitation.UnitTests") }
        let router = FolderInviteRouter(defaults: defaults)
        let link = FolderInviteLink.make()
        router.open(link.url, signedIn: false)
        XCTAssertNil(router.presented)
        let restored = FolderInviteRouter(defaults: defaults)
        XCTAssertEqual(restored.pending, link)
        restored.resume(signedIn: true)
        XCTAssertEqual(restored.presented, link)
        restored.finish()
        XCTAssertNil(FolderInviteRouter(defaults: defaults).pending)
    }

    func testInvitationExpiryAndRevocation() {
        let date = Date(timeIntervalSince1970: 1000)
        let reference = LiveSharedFolder(ownerID: "owner", folderID: "folder", title: "title")
        let invite = FolderInvitation(link: .make(), folder: reference, senderName: "sender", expiresAt: date, isRevoked: false)
        XCTAssertTrue(invite.isAvailable(at: date.addingTimeInterval(-1)))
        XCTAssertFalse(invite.isAvailable(at: date))
        XCTAssertFalse(FolderInvitation(link: .make(), folder: reference, senderName: "sender", expiresAt: date.addingTimeInterval(100), isRevoked: true).isAvailable(at: date))
        XCTAssertEqual(reference.id, LiveSharedFolder(ownerID: "owner", folderID: "folder", title: "renamed").id)
        XCTAssertNotEqual(reference.id, LiveSharedFolder(ownerID: "other", folderID: "folder", title: "title").id)
    }

    func testInvitationReceiveRetriesFailureAndDoesNotCelebrateBeforeCommit() async {
        let repository = RecordingInvitationRepository()
        let model = FolderInvitationModel(repository: repository)
        await model.load(FolderInviteLink.make())
        await model.receive()
        XCTAssertNil(model.received)
        XCTAssertNotNil(model.error)
        XCTAssertFalse(model.isWorking)
        repository.fail = false
        await model.receive()
        XCTAssertNotNil(model.received)
        XCTAssertNil(model.error)
        await model.receive()
        XCTAssertEqual(repository.joins, 2)
    }

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

    func testPhotoRecordRoundTripAndCopiedIdentityPreserveAppleMusicMetadata() throws {
        let track = Track(id: "123", name: "曲名", artist: "歌手", albumImages: ["https://example.com/art.jpg"],
                          previewURL: nil, albumName: "アルバム", musicURL: "https://music.apple.com/jp/song/123",
                          storefront: "jp", isrc: "TEST123")
        let record = PhotoRecord(id: "source-photo", fileName: "photo.jpg", date: nil,
                                 music: FirebaseMusic(photoID: "source-photo", track: track), livePhotoFileName: "live.mov")
        let data = record.firestoreData(date: Timestamp(date: Date(timeIntervalSince1970: 1_700_000_000)))
        let copied = try XCTUnwrap(PhotoRecord(id: "copied-photo", data: data))
        let music = try XCTUnwrap(copied.music)
        XCTAssertEqual(copied.id, "copied-photo")
        XCTAssertEqual(music.id, "copied-photo")
        XCTAssertEqual(music.trackId, track.id)
        XCTAssertEqual(music.provider, .appleMusic)
        XCTAssertEqual(music.track.serviceURL, track.serviceURL)
        XCTAssertEqual(music.storefront, track.storefront)
        XCTAssertEqual(music.isrc, track.isrc)
        XCTAssertEqual(music.albumName, track.albumName)
        XCTAssertEqual(copied.fileName, "photo.jpg")
        XCTAssertEqual(copied.livePhotoFileName, "live.mov")
        XCTAssertNil(music.playablePreviewURL)
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

import FirebaseFirestore

final class LibraryModelTests: XCTestCase {
    func testExistingPhotoRetainsDistinctPhotoAndTrackIDs() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let data: [String: Any] = [
            "url": "photo.jpg", "date": Timestamp(date: date), "livephotoUrl": "live.mov",
            "id": "spotify-track", "artistName": "歌手", "trackName": "曲名",
            "imageName": "https://example.com/artwork.jpg", "previewUrl": "https://example.com/preview.mp3"
        ]
        let record = try XCTUnwrap(PhotoRecord(id: "photo-document", data: data))

        XCTAssertEqual(record.id, "photo-document")
        XCTAssertEqual(record.fileName, "photo.jpg")
        XCTAssertEqual(record.date, date)
        XCTAssertEqual(record.music?.id, "photo-document")
        XCTAssertEqual(record.music?.trackId, "spotify-track")
        XCTAssertEqual(record.livePhotoFileName, "live.mov")

        let saved = record.firestoreData(date: Timestamp(date: date))
        XCTAssertTrue(Set(data.keys).isSubset(of: Set(saved.keys)), "Retain every legacy field")
        XCTAssertEqual(saved["musicProvider"] as? String, "spotify")
        XCTAssertNil(saved["musicURL"], "Do not invent a link for an invalid legacy service ID")
        XCTAssertEqual(saved["id"] as? String, "spotify-track")
        XCTAssertEqual(saved["url"] as? String, "photo.jpg")
        XCTAssertEqual(saved["livephotoUrl"] as? String, "live.mov")
        XCTAssertEqual((saved["date"] as? Timestamp)?.dateValue(), date)
        XCTAssertEqual(saved["previewUrl"] as? String, "https://example.com/preview.mp3")
    }

    func testPhotoWithoutMusicOrDateKeepsPhotoIdentity() throws {
        let record = try XCTUnwrap(PhotoRecord(id: "photo-only", data: ["url": "photo.jpg"]))
        XCTAssertNil(record.music)
        XCTAssertNil(record.date)
        XCTAssertEqual(record.livePhotoFileName, "")
        let saved = record.firestoreData(date: Timestamp(date: Date()))
        XCTAssertNil(saved["id"], "A photo ID must never be saved as a music ID")
        XCTAssertNil(saved["artistName"])
        XCTAssertNil(saved["previewUrl"])
        XCTAssertEqual(Set(saved.keys), ["url", "date", "livephotoUrl"])
    }

    func testPhotoRejectsInvalidStorageFileName() {
        for invalidData: [String: Any] in [[:], ["url": 42], ["url": ""], ["url": " \n "]] {
            XCTAssertNil(PhotoRecord(id: "invalid", data: invalidData))
        }
    }

    func testMissingPreviewAndArtworkDoNotRemoveSelectedTrack() throws {
        let track = Track(id: "track", name: "曲名", artist: "歌手", albumImages: [], previewURL: nil)
        let music = FirebaseMusic(photoID: "photo", track: track)
        let reloaded = try XCTUnwrap(FirebaseMusic(photoID: "photo", data: music.firestoreData))
        XCTAssertEqual(reloaded.trackId, "track")
        XCTAssertEqual(reloaded.trackName, "曲名")
        XCTAssertEqual(reloaded.artistName, "歌手")
        XCTAssertEqual(reloaded.imageName, "")
        XCTAssertEqual(reloaded.previewURL, "")
        XCTAssertNil(reloaded.playablePreviewURL)
        XCTAssertNil(FirebaseMusic(photoID: "photo", data: ["id": ""]))
        XCTAssertNil(FirebaseMusic(photoID: "photo", data: ["trackName": "曲名"]))
    }

    func testPreviewPlaybackAcceptsOnlyWebURLsWithAHost() {
        var music = FirebaseMusic(id: "photo", artistName: "", imageName: "", trackName: "",
                                  trackId: "track", previewURL: "")
        for value in ["", "preview.mp3", "file:///tmp/preview.mp3", "https://"] {
            music.previewURL = value
            XCTAssertNil(music.playablePreviewURL, value)
        }
        for value in ["https://example.com/preview.mp3", "http://example.com/preview.mp3"] {
            music.previewURL = value
            XCTAssertEqual(music.playablePreviewURL?.absoluteString, value)
        }
    }

    func testFolderDecodingPreservesLetterAndDefaultsMissingFields() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let folder = PhotoFolder(id: "folder", data: ["title": "思い出", "date": Timestamp(date: date), "letter": "手紙\n本文"])
        XCTAssertEqual(folder.id, "folder")
        XCTAssertEqual(folder.title, "思い出")
        XCTAssertEqual(folder.date, date)
        XCTAssertEqual(folder.letter, "手紙\n本文")
        XCTAssertEqual(folder.firestoreData(date: Timestamp(date: date))["letter"] as? String, "手紙\n本文")
        let missing = PhotoFolder(id: PhotoFolder.allID, data: [:])
        XCTAssertEqual(missing.id, "all")
        XCTAssertEqual(missing.title, "名称未設定")
        XCTAssertNil(missing.date)
        XCTAssertEqual(missing.letter, "")
    }

    func testLoadedImageRemainsAttachedToItsOwnMetadataWhenAnotherPhotoIsMissing() throws {
        let first = try XCTUnwrap(PhotoRecord(id: "first", data: ["url": "first.jpg", "id": "track-1"]))
        let third = try XCTUnwrap(PhotoRecord(id: "third", data: ["url": "third.jpg", "id": "track-3"]))
        let photos = [LibraryPhoto(record: first, image: UIImage()), LibraryPhoto(record: third, image: UIImage())]
        XCTAssertEqual(photos[1].id, "third")
        XCTAssertEqual(photos[1].record.fileName, "third.jpg")
        XCTAssertEqual(photos[1].record.music?.trackId, "track-3")
        XCTAssertEqual(photos[1].dateText, "")
    }

    func testNFCPayloadKeepsExistingFormatAndRejectsInvalidReferences() {
        let reference = SharedFolderReference(userID: "user", folderID: "folder")
        XCTAssertEqual(reference.payload, "user folder")
        XCTAssertEqual(SharedFolderReference(payload: reference.payload), reference)
        XCTAssertEqual(SharedFolderReference(payload: "user all")?.folderID, PhotoFolder.allID)
        for payload in ["", "user", "user ", " ", "user folder extra", "user folder\n", "user folder/child"] {
            XCTAssertNil(SharedFolderReference(payload: payload), payload)
        }
    }
}

@MainActor
final class PhotoLibraryViewModelTests: XCTestCase {
    private func record(_ id: String, day: Int = 1) -> PhotoRecord {
        PhotoRecord(id: id, fileName: "\(id).jpg", date: Date(timeIntervalSince1970: Double(day * 86_400)),
                    music: FirebaseMusic(id: id, artistName: "歌手", imageName: "", trackName: id,
                                         trackId: "track-\(id)", previewURL: ""), livePhotoFileName: "")
    }

    private func imageData() -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }.pngData()!
    }

    func testFailedMiddleImageCannotShiftPhotoDateOrTrack() async throws {
        let repository = RecordingPhotoLibraryRepository()
        let records = [record("first", day: 1), record("missing", day: 2), record("third", day: 3)]
        repository.photoResults = records
        repository.imageBytes = imageData()
        repository.failedImageNames = ["missing.jpg"]
        let model = MainContentModel(repository: repository, currentUserID: { "user" })

        try await model.loadPhotos(folderID: "folder")

        XCTAssertEqual(model.photos.map(\.id), ["first", "third"])
        XCTAssertEqual(model.photos[1].record.date, records[2].date)
        XCTAssertEqual(model.photos[1].record.music?.trackId, "track-third")
        XCTAssertEqual(model.photos[1].record.fileName, "third.jpg")
        XCTAssertEqual(repository.lastViewedUsers, ["user"])
    }

    func testOlderFolderResponseCannotOverwriteNewSelection() async throws {
        let repository = RecordingPhotoLibraryRepository()
        repository.imageBytes = imageData()
        let firstStarted = expectation(description: "First folder requested")
        let secondStarted = expectation(description: "Second folder requested")
        var completions: [String: CheckedContinuation<[PhotoRecord], Error>] = [:]
        repository.photoLoader = { _, folderID in
            try await withCheckedThrowingContinuation { continuation in
                completions[folderID] = continuation
                (folderID == "first" ? firstStarted : secondStarted).fulfill()
            }
        }
        let model = MainContentModel(repository: repository, currentUserID: { "user" })
        let first = Task { try await model.loadPhotos(folderID: "first") }
        await fulfillment(of: [firstStarted], timeout: 2)
        let second = Task { try await model.loadPhotos(folderID: "second") }
        await fulfillment(of: [secondStarted], timeout: 2)
        completions["second"]?.resume(returning: [record("new")])
        try await second.value
        completions["first"]?.resume(returning: [record("old")])
        try await first.value

        XCTAssertEqual(model.folderDocument, "second")
        XCTAssertEqual(model.photos.map(\.id), ["new"])
        XCTAssertEqual(repository.requestedImageNames, ["new.jpg"])
        XCTAssertEqual(repository.lastViewedUsers, ["user"])
    }

    func testResetDiscardsImageDownloadThatFinishesAfterReset() async throws {
        let repository = RecordingPhotoLibraryRepository()
        repository.photoResults = [record("old")]
        let imageStarted = expectation(description: "Image download started")
        var completion: CheckedContinuation<Data, Error>?
        repository.imageLoader = { _ in
            try await withCheckedThrowingContinuation { continuation in
                completion = continuation
                imageStarted.fulfill()
            }
        }
        let model = MainContentModel(repository: repository, currentUserID: { "user" })
        let pending = Task { try await model.loadPhotos(folderID: "old-folder") }
        await fulfillment(of: [imageStarted], timeout: 2)
        model.reset()
        completion?.resume(returning: imageData())
        try await pending.value

        XCTAssertTrue(model.photos.isEmpty)
        XCTAssertEqual(model.folderDocument, PhotoFolder.allID)
        XCTAssertTrue(repository.lastViewedUsers.isEmpty)

        // Reset must also prevent the old download from repopulating the cache.
        repository.imageLoader = nil
        repository.imageBytes = imageData()
        try await model.loadPhotos(folderID: "new-folder")
        XCTAssertEqual(repository.requestedImageNames, ["old.jpg", "old.jpg"])
    }

    func testLogoutDiscardsPendingPhotoAndFolderResults() async throws {
        let repository = RecordingPhotoLibraryRepository()
        let photosStarted = expectation(description: "Photos requested")
        let foldersStarted = expectation(description: "Folders requested")
        var photoCompletion: CheckedContinuation<[PhotoRecord], Error>?
        var folderCompletion: CheckedContinuation<[PhotoFolder], Error>?
        repository.photoLoader = { _, _ in
            try await withCheckedThrowingContinuation { continuation in
                photoCompletion = continuation
                photosStarted.fulfill()
            }
        }
        repository.folderLoader = { _ in
            try await withCheckedThrowingContinuation { continuation in
                folderCompletion = continuation
                foldersStarted.fulfill()
            }
        }
        var userID: String? = "old-user"
        let model = MainContentModel(repository: repository, currentUserID: { userID })
        let photos = Task { try await model.loadPhotos(folderID: "old-folder") }
        let folders = Task { try await model.getFolder() }
        await fulfillment(of: [photosStarted, foldersStarted], timeout: 2)
        userID = nil
        model.reset()
        photoCompletion?.resume(returning: [record("old-photo")])
        folderCompletion?.resume(returning: [PhotoFolder(id: "old-folder", title: "以前", date: nil, letter: "")])
        try await photos.value
        try await folders.value

        XCTAssertTrue(model.photos.isEmpty)
        XCTAssertTrue(model.folders.isEmpty)
        XCTAssertTrue(repository.requestedImageNames.isEmpty)
        XCTAssertTrue(repository.lastViewedUsers.isEmpty)
    }

    func testAllFolderCannotReachRepositoryDeletion() async {
        let repository = RecordingPhotoLibraryRepository()
        let model = MainContentModel(repository: repository, currentUserID: { "user" })
        for id in [PhotoFolder.allID, ""] {
            do {
                try await model.deleteFolder(id: id)
                XCTFail("Protected or empty folder IDs must fail")
            } catch { }
        }
        XCTAssertTrue(repository.deletedFolders.isEmpty)
    }

    func testNFCFailureClearsBusyFlagAndAllowsRetry() async throws {
        let repository = RecordingPhotoLibraryRepository()
        repository.importFailuresRemaining = 1
        repository.folderResults = [PhotoFolder(id: "shared-folder", title: "共有", date: nil, letter: "手紙")]
        let model = MainContentModel(repository: repository, currentUserID: { "recipient" })
        do {
            try await model.getNFCData(NFCUid: "sender", NFCfolderid: "shared-folder")
            XCTFail("The first import should fail")
        } catch { }
        XCTAssertFalse(model.nfc)
        XCTAssertTrue(model.folders.isEmpty)

        try await model.getNFCData(NFCUid: "sender", NFCfolderid: "shared-folder")

        XCTAssertFalse(model.nfc)
        XCTAssertEqual(repository.importedReferences.count, 2)
        XCTAssertEqual(repository.importedReferences.last?.userID, "recipient")
        XCTAssertEqual(repository.importedReferences.last?.reference,
                       SharedFolderReference(userID: "sender", folderID: "shared-folder"))
        XCTAssertEqual(model.folders.first?.letter, "手紙")
    }

    func testCopySaveAndDeleteUseDocumentIDsInsteadOfArrayPositionsOrTrackIDs() async throws {
        let repository = RecordingPhotoLibraryRepository()
        let model = MainContentModel(repository: repository, currentUserID: { "user" })
        model.folderDocument = "selected-folder"
        model.photos = [LibraryPhoto(record: record("keep"), image: UIImage()),
                        LibraryPhoto(record: record("delete"), image: UIImage())]
        model.folders = [PhotoFolder(id: "other-folder", title: "同じ名前", date: nil, letter: "元の手紙"),
                         PhotoFolder(id: "selected-folder", title: "同じ名前", date: nil, letter: "")]

        try await model.appendFolder(photoDocumentID: "keep", to: "other-folder")
        try await model.saveLetter("更新した手紙", folderID: "selected-folder")
        try await model.deletePhoto(document: "delete", folderId: "selected-folder")

        XCTAssertEqual(repository.copiedPhotos, [.init(userID: "user", photoID: "keep", folderID: "other-folder")])
        XCTAssertEqual(repository.savedLetters, [.init(userID: "user", folderID: "selected-folder", text: "更新した手紙")])
        XCTAssertEqual(repository.deletedPhotos, [.init(userID: "user", photoID: "delete", folderID: "selected-folder")])
        XCTAssertEqual(model.photos.map(\.id), ["keep"])
        XCTAssertEqual(model.photos.first?.record.music?.trackId, "track-keep")
        XCTAssertEqual(model.userDataList, "更新した手紙")
        XCTAssertEqual(model.folders[0].letter, "元の手紙")
        XCTAssertEqual(model.folders[1].letter, "更新した手紙")

        try await model.deleteFolder(id: "selected-folder")
        XCTAssertEqual(repository.deletedFolders, ["selected-folder"])
        XCTAssertEqual(model.folders.map(\.id), ["other-folder"])
        XCTAssertEqual(model.folderDocument, PhotoFolder.allID)
        XCTAssertTrue(model.photos.isEmpty)
        XCTAssertEqual(model.userDataList, "")
    }

    func testLibraryPublishesCompleteRecordsWhileRemainingImagesLoad() async throws {
        let repository = RecordingPhotoLibraryRepository()
        repository.photoResults = [record("first"), record("second")]
        let waiting = expectation(description: "Second image requested")
        let bytes = imageData()
        var completion: CheckedContinuation<Data, Error>?
        repository.imageLoader = { name in
            if name == "first.jpg" { return bytes }
            return try await withCheckedThrowingContinuation { continuation in
                completion = continuation
                waiting.fulfill()
            }
        }
        let model = MainContentModel(repository: repository, currentUserID: { "user" })
        let loading = Task { try await model.firstgetUrl() }
        await fulfillment(of: [waiting], timeout: 2)
        XCTAssertEqual(model.photos.map(\.id), ["first"])
        XCTAssertEqual(model.photos.first?.record.music?.trackId, "track-first")
        completion?.resume(returning: bytes)
        try await loading.value
        XCTAssertEqual(model.photos.map(\.id), ["first", "second"])
    }

    func testPendingReloadCannotRestoreADeletedPhoto() async throws {
        let repository = RecordingPhotoLibraryRepository()
        let started = expectation(description: "Reload started")
        var completion: CheckedContinuation<[PhotoRecord], Error>?
        repository.photoLoader = { _, _ in
            try await withCheckedThrowingContinuation { continuation in
                completion = continuation
                started.fulfill()
            }
        }
        repository.imageBytes = imageData()
        let model = MainContentModel(repository: repository, currentUserID: { "user" })
        let pending = Task { try await model.loadPhotos(folderID: "folder") }
        await fulfillment(of: [started], timeout: 2)
        try await model.deletePhoto(document: "deleted", folderId: "folder")
        completion?.resume(returning: [record("deleted")])
        try await pending.value
        XCTAssertTrue(model.photos.isEmpty)
        XCTAssertTrue(repository.requestedImageNames.isEmpty)
    }

    func testFailedPhotoDeletionLeavesVisiblePhotoIntact() async {
        let repository = RecordingPhotoLibraryRepository()
        repository.failPhotoDeletion = true
        let model = MainContentModel(repository: repository, currentUserID: { "user" })
        model.folderDocument = "folder"
        model.photos = [LibraryPhoto(record: record("photo"), image: UIImage())]
        do {
            try await model.deletePhoto(document: "photo", folderId: "folder")
            XCTFail("Deletion should fail")
        } catch { }
        XCTAssertEqual(model.photos.map(\.id), ["photo"])
    }
}

@MainActor
private final class RecordingPhotoLibraryRepository: PhotoLibraryRepository {
    struct PhotoOperation: Equatable {
        let userID: String
        let photoID: String
        let folderID: String
    }
    struct LetterOperation: Equatable {
        let userID: String
        let folderID: String
        let text: String
    }
    struct ImportOperation {
        let userID: String
        let reference: SharedFolderReference
    }
    var photoResults: [PhotoRecord] = []
    var folderResults: [PhotoFolder] = []
    var imageBytes = Data()
    var failedImageNames: Set<String> = []
    var photoLoader: ((String, String) async throws -> [PhotoRecord])?
    var folderLoader: ((String) async throws -> [PhotoFolder])?
    var imageLoader: ((String) async throws -> Data)?
    var requestedImageNames: [String] = []
    var copiedPhotos: [PhotoOperation] = []
    var deletedPhotos: [PhotoOperation] = []
    var deletedFolders: [String] = []
    var savedLetters: [LetterOperation] = []
    var importedReferences: [ImportOperation] = []
    var lastViewedUsers: [String] = []
    var importFailuresRemaining = 0
    var failPhotoDeletion = false

    func photos(userID: String, folderID: String) async throws -> [PhotoRecord] {
        if let photoLoader { return try await photoLoader(userID, folderID) }
        return photoResults
    }
    func coverPhoto(userID: String, folderID: String) async throws -> PhotoRecord? {
        photoResults.last
    }
    func imageData(fileName: String) async throws -> Data {
        requestedImageNames.append(fileName)
        if failedImageNames.contains(fileName) { throw failure() }
        if let imageLoader { return try await imageLoader(fileName) }
        return imageBytes
    }
    func folders(userID: String) async throws -> [PhotoFolder] {
        if let folderLoader { return try await folderLoader(userID) }
        return folderResults
    }
    func createFolder(userID: String, folder: PhotoFolder) async throws { }
    func copyPhoto(userID: String, photoID: String, to folderID: String) async throws {
        copiedPhotos.append(PhotoOperation(userID: userID, photoID: photoID, folderID: folderID))
    }
    func deletePhoto(userID: String, photoID: String, folderID: String) async throws {
        if failPhotoDeletion { throw failure() }
        deletedPhotos.append(PhotoOperation(userID: userID, photoID: photoID, folderID: folderID))
    }
    func deleteFolder(userID: String, folderID: String) async throws {
        deletedFolders.append(folderID)
    }
    func letter(userID: String, folderID: String) async throws -> String { "" }
    func saveLetter(userID: String, folderID: String, text: String) async throws {
        savedLetters.append(LetterOperation(userID: userID, folderID: folderID, text: text))
    }
    func importFolder(userID: String, reference: SharedFolderReference) async throws {
        importedReferences.append(ImportOperation(userID: userID, reference: reference))
        if importFailuresRemaining > 0 {
            importFailuresRemaining -= 1
            throw failure()
        }
    }
    func updateLibraryDate(userID: String) async throws { }
    func updateLastViewedDate(userID: String) async throws { lastViewedUsers.append(userID) }
    func downloadURL(fileName: String) async throws -> URL { throw failure() }
    private func failure() -> Error { NSError(domain: "LibraryRepositoryTest", code: 1) }
}

final class UserProfileModelTests: XCTestCase {
    func testMissingNameRemainsDifferentFromAnExplicitEmptyName() {
        XCTAssertNil(UserProfile(documentData: [:]).name)
        XCTAssertNil(UserProfile(documentData: ["name": 42]).name)
        XCTAssertEqual(UserProfile(documentData: ["name": ""]).name, "")
        XCTAssertEqual(UserProfile(documentData: ["name": "名前"]).name, "名前")
    }

    func testEmailFallbackOnlyAppliesWhenTheStoredValueIsMissingOrInvalid() {
        XCTAssertEqual(UserProfile(documentData: [:], fallbackEmail: "auth@example.com").email, "auth@example.com")
        XCTAssertEqual(UserProfile(documentData: ["email": 42], fallbackEmail: "auth@example.com").email, "auth@example.com")
        XCTAssertEqual(UserProfile(documentData: ["email": ""], fallbackEmail: "auth@example.com").email, "")
        XCTAssertEqual(UserProfile(documentData: ["email": "saved@example.com"], fallbackEmail: "auth@example.com").email, "saved@example.com")
        XCTAssertNil(UserProfile(documentData: [:]).email)
    }
}

@MainActor
final class FriendQRViewModelTests: XCTestCase {
    func testValidProfileKeepsScannedUserIDAndConfirmationName() async {
        var requestedID: String?
        let model = FriendQRViewModel { uid in
            requestedID = uid
            return UserProfile(name: "友人")
        }
        let friend = await model.loadFriendProfile(uid: "friend-id")
        XCTAssertEqual(requestedID, "friend-id")
        XCTAssertEqual(friend, "friend-id")
        XCTAssertEqual(model.alertMessage, " 友人さんと撮ります")
        XCTAssertTrue(model.showAlert)
    }

    func testMissingIncompleteAndFailedProfilesDoNotReturnAFriend() async {
        let missing = FriendQRViewModel { _ in nil }
        let incomplete = FriendQRViewModel { _ in UserProfile() }
        let failed = FriendQRViewModel { _ in throw NSError(domain: "ProfileTest", code: 1) }
        for model in [missing, incomplete, failed] {
            let friend = await model.loadFriendProfile(uid: "friend-id")
            XCTAssertNil(friend)
            XCTAssertTrue(model.showAlert)
        }
        XCTAssertEqual(missing.alertMessage, "User info not found")
        XCTAssertEqual(incomplete.alertMessage, "User info is incomplete")
        XCTAssertEqual(failed.alertMessage, "Error getting user info")
    }

    func testProfileWritesRetainLegacyFieldsAndEmptyFallbacks() {
        let data = UserProfile().firestoreData(userID: "user")
        XCTAssertEqual(data["uid"] as? String, "user")
        XCTAssertEqual(data["email"] as? String, "")
        XCTAssertEqual(data["name"] as? String, "")
        XCTAssertEqual(Set(data.keys), Set(["uid", "email", "name"]))
    }
}

private final class RecordingInvitationRepository: FolderInvitationRepository {
    var fail = true
    var joins = 0
    func create(folderID: String) async throws -> FolderInvitation { try await resolve(link: .make()) }
    func resolve(link: FolderInviteLink) async throws -> FolderInvitation {
        FolderInvitation(link: link, folder: LiveSharedFolder(ownerID: "owner", folderID: "folder", title: "title"), senderName: "sender", expiresAt: Date().addingTimeInterval(600), isRevoked: false)
    }
    func join(invitation: FolderInvitation) async throws -> LiveSharedFolder {
        joins += 1
        if fail { throw URLError(.notConnectedToInternet) }
        return invitation.folder
    }
    func revoke(link: FolderInviteLink) async throws { }
    func sharedFolders() async throws -> [LiveSharedFolder] { [] }
    func observe(_ folder: LiveSharedFolder) -> AsyncThrowingStream<SharedFolderUpdate, Error> { AsyncThrowingStream { $0.finish() } }
}
