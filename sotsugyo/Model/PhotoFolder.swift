import Foundation
import FirebaseFirestore

struct PhotoFolder: Identifiable {
    static let allID = "all"

    let id: String
    let title: String
    let date: Date?
    let letter: String
}

extension PhotoFolder {
    init(id: String, data: [String: Any]) {
        self.init(id: id, title: data["title"] as? String ?? "名称未設定",
                  date: (data["date"] as? Timestamp)?.dateValue(),
                  letter: data["letter"] as? String ?? "")
    }

    func firestoreData(date: Any) -> [String: Any] {
        ["title": title, "date": date, "letter": letter]
    }
}
