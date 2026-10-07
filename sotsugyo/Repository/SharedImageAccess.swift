import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

/// A grant is validated by Firestore against the actual source photo and membership.
/// Storage rechecks the source folder on every read, including after deletion/removal.
enum SharedImageAccess {
    static func load(folder: LiveSharedFolder, photo: PhotoRecord) async throws -> Data {
        guard let uid = Auth.auth().currentUser?.uid else { throw FolderInviteError.signInRequired }
        try await Firestore.firestore().collection("users").document(uid).collection("imageAccess").document(photo.fileName)
            .setData(["ownerID": folder.ownerID, "folderID": folder.folderID, "photoID": photo.id])
        return try await Storage.storage().reference().child("images/\(photo.fileName)").data(maxSize: 100 * 1024 * 1024)
    }
}

struct CameraInvitation {
    let token: String
    let ownerID: String
    let name: String
    var payload: String { "pictune-camera:\(token)" }
}

enum CameraInvitationService {
    static func create() async throws -> CameraInvitation {
        guard let user = Auth.auth().currentUser else { throw FolderInviteError.signInRequired }
        let profile = try await Firestore.firestore().collection("users").document(user.uid).collection("personal").document("info").getDocument()
        let invitation = CameraInvitation(token: FolderInviteLink.make().token, ownerID: user.uid,
                                          name: profile.data()?["name"] as? String ?? "お友達")
        try await Firestore.firestore().collection("cameraInvites").document(invitation.token).setData([
            "ownerID": user.uid, "name": invitation.name,
            "expiresAt": Timestamp(date: Date().addingTimeInterval(15 * 60)), "createdAt": FieldValue.serverTimestamp()
        ])
        return invitation
    }
    static func accept(payload: String) async throws -> CameraInvitation {
        guard let uid = Auth.auth().currentUser?.uid else { throw FolderInviteError.signInRequired }
        guard payload.hasPrefix("pictune-camera:") else { throw FolderInviteError.invalidLink }
        let token = String(payload.dropFirst("pictune-camera:".count))
        guard let url = URL(string: "pictune://invite/\(token)"), FolderInviteLink(url: url) != nil else { throw FolderInviteError.invalidLink }
        let snapshot = try await Firestore.firestore().collection("cameraInvites").document(token).getDocument(source: .server)
        guard let data = snapshot.data(), let owner = data["ownerID"] as? String,
              let expires = data["expiresAt"] as? Timestamp, expires.dateValue() > Date(), owner != uid else { throw FolderInviteError.unavailable }
        try await Firestore.firestore().collection("users").document(owner).collection("photoSenders").document(uid)
            .setData(["inviteToken": token, "expiresAt": expires])
        return CameraInvitation(token: token, ownerID: owner, name: data["name"] as? String ?? "お友達")
    }
}
