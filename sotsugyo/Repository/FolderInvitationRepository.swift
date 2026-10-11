import Foundation
import FirebaseAuth
import FirebaseFirestore

protocol FolderInvitationRepository {
    func create(folderID: String) async throws -> FolderInvitation
    func resolve(link: FolderInviteLink) async throws -> FolderInvitation
    func join(invitation: FolderInvitation) async throws -> LiveSharedFolder
    func revoke(link: FolderInviteLink) async throws
    func sharedFolders() async throws -> [LiveSharedFolder]
    func observe(_ folder: LiveSharedFolder) -> AsyncThrowingStream<SharedFolderUpdate, Error>
}

enum SharedFolderUpdate {
    case folder(PhotoFolder)
    case photos([PhotoRecord])
}

struct FirebaseFolderInvitationRepository: FolderInvitationRepository {
    private var database: Firestore { Firestore.firestore() }
    private func userID() throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else { throw FolderInviteError.signInRequired }
        return uid
    }
    private func source(_ folder: LiveSharedFolder) -> DocumentReference {
        database.collection("users").document(folder.ownerID).collection("folders").document(folder.folderID)
    }
    private func decode(_ document: DocumentSnapshot) throws -> FolderInvitation {
        guard let data = document.data(), let owner = data["ownerID"] as? String,
              let folder = data["folderID"] as? String,
              let expires = data["expiresAt"] as? Timestamp else { throw FolderInviteError.unavailable }
        return FolderInvitation(link: FolderInviteLink(token: document.documentID),
                                folder: LiveSharedFolder(ownerID: owner, folderID: folder, title: data["title"] as? String ?? "思い出のフォルダ"),
                                senderName: data["senderName"] as? String ?? "お友達",
                                expiresAt: expires.dateValue(), isRevoked: data["revoked"] as? Bool ?? true)
    }

    func create(folderID: String) async throws -> FolderInvitation {
        let uid = try userID()
        guard folderID != PhotoFolder.allID else { throw FolderInviteError.missingFolder }
        let pointer = database.collection("users").document(uid).collection("folderInviteLinks").document(folderID)
        let existing = try await pointer.getDocument(source: .server)
        if let token = existing.data()?["token"] as? String {
            let old = try await database.collection("folderInvites").document(token).getDocument(source: .server)
            if let invite = try? decode(old), invite.isAvailable() { return invite }
        }
        let reference = database.collection("users").document(uid).collection("folders").document(folderID)
        let folder = try await reference.getDocument(source: .server)
        guard folder.exists else { throw FolderInviteError.missingFolder }
        let title = folder.data()?["title"] as? String ?? "思い出のフォルダ"
        let profile = try await database.collection("users").document(uid).collection("personal").document("info").getDocument()
        let sender = profile.data()?["name"] as? String ?? "お友達"
        let link = FolderInviteLink.make()
        let expires = Date().addingTimeInterval(7 * 24 * 60 * 60)
        let batch = database.batch()
        batch.setData([
            "ownerID": uid, "folderID": folderID, "title": title, "senderName": sender,
            "createdAt": FieldValue.serverTimestamp(), "expiresAt": Timestamp(date: expires), "revoked": false
        ], forDocument: database.collection("folderInvites").document(link.token))
        batch.setData(["token": link.token], forDocument: pointer)
        try await batch.commit()
        guard try userID() == uid else { throw FolderInviteError.signInRequired }
        return FolderInvitation(link: link, folder: LiveSharedFolder(ownerID: uid, folderID: folderID, title: title),
                                senderName: sender, expiresAt: expires, isRevoked: false)
    }

    func resolve(link: FolderInviteLink) async throws -> FolderInvitation {
        let uid = try userID()
        let invite: FolderInvitation
        do { invite = try decode(await database.collection("folderInvites").document(link.token).getDocument(source: .server)) }
        catch let error as NSError where error.domain == FirestoreErrorDomain && error.code == FirestoreErrorCode.permissionDenied.rawValue {
            throw FolderInviteError.unavailable
        }
        guard try userID() == uid else { throw FolderInviteError.signInRequired }
        guard invite.isAvailable() else { throw FolderInviteError.unavailable }
        guard invite.folder.ownerID != uid else { throw FolderInviteError.ownFolder }
        return invite
    }

    func join(invitation: FolderInvitation) async throws -> LiveSharedFolder {
        let uid = try userID()
        let fresh = try await resolve(link: invitation.link)
        let member = source(fresh.folder)
        let saved = database.collection("users").document(uid).collection("sharedFolders").document(fresh.folder.id)
        // A single commit prevents a half-joined folder. Deterministic IDs make retries idempotent.
        let batch = database.batch()
        batch.updateData(["inviteToken": fresh.link.token, "sharedWith": FieldValue.arrayUnion([uid])], forDocument: member)
        batch.setData(["ownerID": fresh.folder.ownerID, "folderID": fresh.folder.folderID,
                       "title": fresh.folder.title, "joinedAt": FieldValue.serverTimestamp()], forDocument: saved)
        try await batch.commit()
        guard try userID() == uid else { throw FolderInviteError.signInRequired }
        return fresh.folder
    }

    func revoke(link: FolderInviteLink) async throws {
        _ = try userID()
        try await database.collection("folderInvites").document(link.token).updateData(["revoked": true])
    }

    func sharedFolders() async throws -> [LiveSharedFolder] {
        let uid = try userID()
        let snapshot = try await database.collection("users").document(uid).collection("sharedFolders").getDocuments(source: .server)
        guard try userID() == uid else { throw FolderInviteError.signInRequired }
        return snapshot.documents.compactMap { document in
            let data = document.data()
            guard let owner = data["ownerID"] as? String, let folder = data["folderID"] as? String else { return nil }
            return LiveSharedFolder(ownerID: owner, folderID: folder, title: data["title"] as? String ?? "思い出のフォルダ")
        }
    }

    func observeLibrary() -> AsyncThrowingStream<[LiveSharedFolder], Error> {
        AsyncThrowingStream { continuation in
            guard let uid = try? userID() else { continuation.finish(throwing: FolderInviteError.signInRequired); return }
            let listener = database.collection("users").document(uid).collection("sharedFolders").addSnapshotListener { snapshot, error in
                if let error { continuation.finish(throwing: error); return }
                guard let snapshot else { return }
                continuation.yield(snapshot.documents.compactMap { document in
                    let data = document.data()
                    guard let owner = data["ownerID"] as? String, let folder = data["folderID"] as? String else { return nil }
                    return LiveSharedFolder(ownerID: owner, folderID: folder, title: data["title"] as? String ?? "思い出のフォルダ")
                })
            }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    func observe(_ folder: LiveSharedFolder) -> AsyncThrowingStream<SharedFolderUpdate, Error> {
        AsyncThrowingStream { continuation in
            let reference = source(folder)
            let metadata = reference.addSnapshotListener { snapshot, error in
                if let error { continuation.finish(throwing: error); return }
                guard let snapshot, snapshot.exists else { continuation.finish(throwing: FolderInviteError.missingFolder); return }
                continuation.yield(.folder(PhotoFolder(id: snapshot.documentID, data: snapshot.data() ?? [:])))
            }
            let photos = reference.collection("photos").order(by: "date").addSnapshotListener { snapshot, error in
                if let error { continuation.finish(throwing: error); return }
                guard let snapshot else { return }
                continuation.yield(.photos(snapshot.documents.compactMap { PhotoRecord(id: $0.documentID, data: $0.data()) }))
            }
            continuation.onTermination = { _ in metadata.remove(); photos.remove() }
        }
    }
}
