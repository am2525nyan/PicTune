import Foundation
import UIKit

/// Shared by the app tests and the widget extension. The app supplies authenticated image copies.
enum WidgetPhotoLoader {
    static let keys = ["first", "second", "third"]
    typealias Read = @Sendable (URL) async throws -> Data

    static func loadImages(defaults: UserDefaults? = UserDefaults(suiteName: "group.PIcTune"),
                           directory: URL? = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.PIcTune"),
                           read: @escaping Read = { try Data(contentsOf: $0) }) async -> [UIImage] {
        guard let directory else { return [] }
        let initialValues = keys.map { defaults?.string(forKey: $0) }
        let urls = zip(keys, initialValues).compactMap { key, value -> URL? in
            let expected = directory.appendingPathComponent("widget-\(key).jpg")
            guard value == expected.path else { return nil }
            return expected
        }

        let data = await withTaskGroup(of: (Int, Data?).self) { group in
            for (index, url) in urls.enumerated() {
                group.addTask {
                    do { return (index, try await read(url)) }
                    catch { return (index, nil) }
                }
            }
            var results: [(Int, Data)] = []
            for await (index, data) in group {
                if let data { results.append((index, data)) }
            }
            return results.sorted { $0.0 < $1.0 }.map(\.1)
        }
        // Logout and newer library updates invalidate reads already in progress.
        guard initialValues == keys.map({ defaults?.string(forKey: $0) }) else { return [] }
        return data.compactMap { UIImage(data: $0) }
    }
}
