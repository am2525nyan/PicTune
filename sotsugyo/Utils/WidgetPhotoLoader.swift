import Foundation
import UIKit

/// Shared by the app tests and the widget extension.
enum WidgetPhotoLoader {
    static let keys = ["first", "second", "third"]
    typealias Fetch = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    static func loadImages(defaults: UserDefaults? = UserDefaults(suiteName: "group.PIcTune"),
                           fetch: @escaping Fetch = { try await URLSession.shared.data(for: $0) }) async -> [UIImage] {
        let initialValues = keys.map { defaults?.string(forKey: $0) }
        let urls = initialValues.compactMap { value -> URL? in
            guard let value,
                  let url = URL(string: value), url.scheme == "https",
                  let host = url.host, !host.isEmpty else { return nil }
            return url
        }

        // Fetch concurrently with a bounded timeout so a missing image cannot block the timeline.
        let data = await withTaskGroup(of: (Int, Data?).self) { group in
            for (index, url) in urls.enumerated() {
                group.addTask {
                    do {
                        let request = URLRequest(url: url, timeoutInterval: 10)
                        let (data, response) = try await fetch(request)
                        guard let response = response as? HTTPURLResponse,
                              (200..<300).contains(response.statusCode) else { return (index, nil) }
                        return (index, data)
                    } catch {
                        return (index, nil)
                    }
                }
            }
            var results: [(Int, Data)] = []
            for await (index, data) in group {
                if let data { results.append((index, data)) }
            }
            return results.sorted { $0.0 < $1.0 }.map(\.1)
        }
        // Logout and newer library updates invalidate downloads already in progress.
        guard initialValues == keys.map({ defaults?.string(forKey: $0) }) else { return [] }
        return data.compactMap { UIImage(data: $0) }
    }
}
