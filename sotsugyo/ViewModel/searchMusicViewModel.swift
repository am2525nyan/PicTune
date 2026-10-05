import Foundation
import Combine

@MainActor
final class SearchViewModel: ObservableObject {
    typealias SearchOperation = (String) async throws -> [Track]

    @Published var searchText = ""
    @Published var selection: Track?
    @Published private(set) var tracks: [Track] = []
    @Published private(set) var isSearching = false
    @Published private(set) var searchError: String?
    @Published private(set) var resultsQuery = ""
    @Published private(set) var recentSearches: [String]

    private let defaults: UserDefaults
    private let searchOperation: SearchOperation
    private var requestID = UUID()
    private static let historyKey = "music.recentSearches"

    var query: String { searchText.trimmingCharacters(in: .whitespacesAndNewlines) }

    init(selection: Track? = nil, defaults: UserDefaults = .standard,
         search: @escaping SearchOperation = { query in
             try await withCheckedThrowingContinuation { continuation in
                 SpotifyAPI.shared.searchTracks(query: query) { result in
                     continuation.resume(with: result)
                 }
             }
         }) {
        self.selection = selection
        self.defaults = defaults
        self.searchOperation = search
        self.recentSearches = defaults.stringArray(forKey: Self.historyKey) ?? []
    }

    func search(debounce: Bool = true) async {
        let query = self.query
        let requestID = UUID()
        self.requestID = requestID
        searchError = nil
        guard !query.isEmpty else {
            tracks = []
            resultsQuery = ""
            isSearching = false
            return
        }

        // Keep the previous results visible while updating, but never apply an obsolete response.
        isSearching = true
        do {
            if debounce { try await Task.sleep(for: .milliseconds(300)) }
            try Task.checkCancellation()
            let results = try await searchOperation(query)
            guard self.requestID == requestID, self.query == query, !Task.isCancelled else { return }
            tracks = results
            resultsQuery = query
            isSearching = false
        } catch {
            guard self.requestID == requestID else { return }
            isSearching = false
            guard !Task.isCancelled, !(error is CancellationError), self.query == query else { return }
            searchError = "通信状況を確認して、もう一度お試しください。"
        }
    }

    func select(_ track: Track) {
        selection = track
        remember(resultsQuery)
    }

    func remember(_ text: String) {
        let term = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }
        recentSearches.removeAll { $0.caseInsensitiveCompare(term) == .orderedSame }
        recentSearches.insert(term, at: 0)
        recentSearches = Array(recentSearches.prefix(8))
        defaults.set(recentSearches, forKey: Self.historyKey)
    }

    func useRecentSearch(_ term: String) {
        remember(term)
        searchText = term
    }

    func clearHistory() {
        recentSearches = []
        defaults.removeObject(forKey: Self.historyKey)
    }
}
