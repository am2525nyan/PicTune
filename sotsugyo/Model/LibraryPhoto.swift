import Foundation
import UIKit

/// Keeps a downloaded image together with the metadata for the same document.
struct LibraryPhoto: Identifiable {
    let record: PhotoRecord
    let image: UIImage

    var id: String { record.id }

    var dateText: String {
        guard let date = record.date else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH:mm"
        return formatter.string(from: date)
    }
}
