import XCTest
import UIKit
@testable import PIcTune

@MainActor
final class MusicRegressionTests: XCTestCase {
    private let widgetDirectory = URL(fileURLWithPath: "/test-widget")
    func testWidgetDiscardsInFlightPhotosAfterSharedPathsAreCleared() async throws {
        let domain = "WidgetRegressionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.set(widgetDirectory.appendingPathComponent("widget-first.jpg").path, forKey: "first")
        let data = try XCTUnwrap(UIGraphicsImageRenderer(size: CGSize(width: 12, height: 18)).image { _ in }.pngData())
        let started = expectation(description: "Read started")
        let gate = WidgetReadGate()
        let task = Task {
            await WidgetPhotoLoader.loadImages(defaults: defaults, directory: widgetDirectory) { url in
                await gate.wait(started: started)
                return data
            }
        }
        await fulfillment(of: [started], timeout: 2)
        WidgetPhotoLoader.keys.forEach { defaults.removeObject(forKey: $0) }
        await gate.resume()
        let images = await task.value
        XCTAssertTrue(images.isEmpty, "An in-flight read must not restore a signed-out user's photos")
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

    func testWidgetWithoutSharedDefaultsDoesNotReadOrCrash() async {
        let images = await WidgetPhotoLoader.loadImages(defaults: nil, directory: widgetDirectory) { _ in
            XCTFail("Missing shared defaults must not trigger an image read")
            throw URLError(.badURL)
        }
        XCTAssertTrue(images.isEmpty)
    }

    func testWidgetWithOnlyOnePhotoAndInvalidPathsKeepsValidPhoto() async throws {
        let domain = "WidgetRegressionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.set(widgetDirectory.appendingPathComponent("widget-first.jpg").path, forKey: "first")
        defaults.set("https://example.com/public.png", forKey: "second")
        defaults.set("/outside/widget-third.jpg", forKey: "third")
        let data = try XCTUnwrap(UIGraphicsImageRenderer(size: CGSize(width: 12, height: 18)).image { _ in }.pngData())
        let images = await WidgetPhotoLoader.loadImages(defaults: defaults, directory: widgetDirectory) { url in
            XCTAssertEqual(url.path, "/test-widget/widget-first.jpg")
            return data
        }
        XCTAssertEqual(images.count, 1)
        XCTAssertEqual(images.first?.size.width, UIImage(data: data)?.size.width)
    }

    func testWidgetSkipsMissingUnreadableAndCorruptImage() async {
        let domain = "WidgetRegressionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        for key in WidgetPhotoLoader.keys {
            defaults.set(widgetDirectory.appendingPathComponent("widget-\(key).jpg").path, forKey: key)
        }
        let images = await WidgetPhotoLoader.loadImages(defaults: defaults, directory: widgetDirectory) { url in
            if url.lastPathComponent == "widget-first.jpg" { throw CocoaError(.fileReadNoPermission) }
            if url.lastPathComponent == "widget-second.jpg" { throw CocoaError(.fileReadNoSuchFile) }
            return Data("invalid image".utf8)
        }
        XCTAssertTrue(images.isEmpty)
    }

    func testWidgetKeepsPhotoOrderWhenReadsFinishOutOfOrder() async throws {
        let domain = "WidgetRegressionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.set(widgetDirectory.appendingPathComponent("widget-first.jpg").path, forKey: "first")
        defaults.set(widgetDirectory.appendingPathComponent("widget-second.jpg").path, forKey: "second")
        let firstData = try XCTUnwrap(UIGraphicsImageRenderer(size: CGSize(width: 12, height: 18)).image { _ in }.pngData())
        let secondData = try XCTUnwrap(UIGraphicsImageRenderer(size: CGSize(width: 24, height: 18)).image { _ in }.pngData())
        let images = await WidgetPhotoLoader.loadImages(defaults: defaults, directory: widgetDirectory) { url in
            let first = url.lastPathComponent == "widget-first.jpg"
            if first { try await Task.sleep(for: .milliseconds(30)) }
            return first ? firstData : secondData
        }
        XCTAssertEqual(images.map(\.size.width), [UIImage(data: firstData)!.size.width, UIImage(data: secondData)!.size.width])
    }
}

private actor WidgetReadGate {
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
