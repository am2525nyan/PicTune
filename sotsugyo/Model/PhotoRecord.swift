import Foundation
import FirebaseFirestore

/// Metadata for one photo document, using the existing flat Firestore format.
struct PhotoRecord: Identifiable {
    let id: String
    let fileName: String
    let date: Date?
    let music: FirebaseMusic?
    let livePhotoFileName: String
}

extension PhotoRecord {
    init?(id: String, data: [String: Any]) {
        guard let fileName = data["url"] as? String,
              !fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        self.init(id: id, fileName: fileName,
                  date: (data["date"] as? Timestamp)?.dateValue(),
                  music: FirebaseMusic(photoID: id, data: data),
                  livePhotoFileName: data["livephotoUrl"] as? String ?? "")
    }

    /// The caller supplies a Timestamp or FieldValue.serverTimestamp() as appropriate.
    /// Copies of existing documents should retain their raw fields in the repository.
    func firestoreData(date: Any) -> [String: Any] {
        var data: [String: Any] = [
            "url": fileName, "date": date, "livephotoUrl": livePhotoFileName
        ]
        if let music {
            data.merge(music.firestoreData) { _, newValue in newValue }
        }
        return data
    }
}
