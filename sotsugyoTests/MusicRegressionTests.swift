import XCTest
import UIKit
@testable import PIcTune

@MainActor
final class MusicRegressionTests: XCTestCase {
    func testWidgetDiscardsInFlightPhotosAfterSharedURLsAreCleared() async throws {
        let domain = "WidgetRegressionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.set("https://example.com/previous-user.png", forKey: "first")
        let data = try XCTUnwrap(UIGraphicsImageRenderer(size: CGSize(width: 12, height: 18)).image { _ in }.pngData())
        let started = expectation(description: "Download started")
        let gate = WidgetDownloadGate()
        let task = Task {
            await WidgetPhotoLoader.loadImages(defaults: defaults) { request in
                await gate.wait(started: started)
                return (data, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
            }
        }
        await fulfillment(of: [started], timeout: 2)
        WidgetPhotoLoader.keys.forEach { defaults.removeObject(forKey: $0) }
        await gate.resume()
        let images = await task.value
        XCTAssertTrue(images.isEmpty, "An in-flight download must not restore a signed-out user's photos")
    }

    func testCancelledSearchClearsLoadingWhenOperationReturnsAfterCancellation() async {
        let domain = "MusicRegressionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        let started = expectation(description: "Search started")
        var completion: CheckedContinuation<[Track], Error>?
        let model = SearchViewModel(defaults: defaults, search: { _ in
            try await withCheckedThrowingContinuation {
                completion = $0
                started.fulfill()
            }
        })
        model.searchText = "song"
        let task = Task { await model.search(debounce: false) }
        await fulfillment(of: [started], timeout: 2)
        XCTAssertTrue(model.isSearching)
        task.cancel()
        completion?.resume(returning: [Track(id: "123", name: "song", artist: "artist", albumImages: [])])
        await task.value
        XCTAssertFalse(model.isSearching)
        XCTAssertTrue(model.tracks.isEmpty)
        XCTAssertNil(model.searchError)
    }

    func testWidgetWithoutSharedDefaultsDoesNotFetchOrCrash() async {
        let images = await WidgetPhotoLoader.loadImages(defaults: nil) { _ in
            XCTFail("Missing shared defaults must not trigger a network request")
            throw URLError(.badURL)
        }
        XCTAssertTrue(images.isEmpty)
    }

    func testWidgetWithOnlyOnePhotoAndInvalidURLsKeepsValidPhoto() async throws {
        let domain = "WidgetRegressionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.set("https://example.com/photo.png", forKey: "first")
        defaults.set("not a URL", forKey: "second")
        let data = try XCTUnwrap(UIGraphicsImageRenderer(size: CGSize(width: 12, height: 18)).image { _ in }.pngData())
        let images = await WidgetPhotoLoader.loadImages(defaults: defaults) { request in
            XCTAssertEqual(request.url?.path, "/photo.png")
            XCTAssertEqual(request.timeoutInterval, 10)
            return (data, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        XCTAssertEqual(images.count, 1)
        XCTAssertEqual(images.first?.size.width, UIImage(data: data)?.size.width)
    }

    func testWidgetSkipsNetworkFailureHTTPErrorAndCorruptImage() async {
        let domain = "WidgetRegressionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        for (key, path) in zip(WidgetPhotoLoader.keys, ["offline", "missing", "corrupt"]) {
            defaults.set("https://example.com/\(path)", forKey: key)
        }
        let images = await WidgetPhotoLoader.loadImages(defaults: defaults) { request in
            if request.url?.path == "/offline" { throw URLError(.notConnectedToInternet) }
            let status = request.url?.path == "/missing" ? 404 : 200
            return (Data("invalid image".utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
        }
        XCTAssertTrue(images.isEmpty)
    }

    func testWidgetKeepsPhotoOrderWhenDownloadsFinishOutOfOrder() async throws {
        let domain = "WidgetRegressionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.set("https://example.com/first", forKey: "first")
        defaults.set("https://example.com/second", forKey: "second")
        let firstData = try XCTUnwrap(UIGraphicsImageRenderer(size: CGSize(width: 12, height: 18)).image { _ in }.pngData())
        let secondData = try XCTUnwrap(UIGraphicsImageRenderer(size: CGSize(width: 24, height: 18)).image { _ in }.pngData())
        let images = await WidgetPhotoLoader.loadImages(defaults: defaults) { request in
            let first = request.url?.path == "/first"
            if first { try await Task.sleep(for: .milliseconds(30)) }
            return (first ? firstData : secondData,
                    HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        XCTAssertEqual(images.map(\.size.width), [UIImage(data: firstData)!.size.width, UIImage(data: secondData)!.size.width])
    }
}

private actor WidgetDownloadGate {
    private var continuation: CheckedContinuation<Void, Never>?

    func wait(started: XCTestExpectation) async {
        await withCheckedContinuation {
            continuation = $0
            started.fulfill()
        }
    }

    func resume() {
        continuation?.resume()
        continuation = nil
    }
}
