import Foundation

/// The existing NFC payload: a user ID and a folder ID separated by one space.
struct SharedFolderReference: Equatable {
    let userID: String
    let folderID: String

    var payload: String { "\(userID) \(folderID)" }
}

extension SharedFolderReference {
    init?(payload: String) {
        let parts = payload.split(separator: " ", maxSplits: 1).map(String.init)
        guard parts.count == 2,
              parts.allSatisfy({ !$0.isEmpty && !$0.contains("/") &&
                  $0.rangeOfCharacter(from: .whitespacesAndNewlines) == nil }) else { return nil }
        self.init(userID: parts[0], folderID: parts[1])
    }
}
