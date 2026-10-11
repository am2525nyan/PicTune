import SwiftUI
import FirebaseAuth

@MainActor
final class FolderInvitationModel: ObservableObject {
    @Published private(set) var invitation: FolderInvitation?
    @Published private(set) var received: LiveSharedFolder?
    @Published private(set) var isWorking = false
    @Published private(set) var isRevoked = false
    @Published var error: String?
    let repository: any FolderInvitationRepository

    init(repository: any FolderInvitationRepository = FirebaseFolderInvitationRepository()) { self.repository = repository }

    func load(_ link: FolderInviteLink) async {
        guard !isWorking else { return }
        isWorking = true; error = nil
        defer { isWorking = false }
        do { invitation = try await repository.resolve(link: link) }
        catch { self.error = error.localizedDescription }
    }
    func create(folderID: String) async {
        guard !isWorking else { return }
        isWorking = true; error = nil
        defer { isWorking = false }
        do { invitation = try await repository.create(folderID: folderID); isRevoked = false }
        catch { self.error = error.localizedDescription }
    }
    func receive() async {
        guard let invitation, !isWorking, received == nil else { return }
        isWorking = true; error = nil
        defer { isWorking = false }
        do { received = try await repository.join(invitation: invitation) }
        catch { self.error = error.localizedDescription }
    }
    func revoke() async {
        guard let invitation, !isWorking else { return }
        isWorking = true; error = nil
        defer { isWorking = false }
        do { try await repository.revoke(link: invitation.link); isRevoked = true }
        catch { self.error = error.localizedDescription }
    }
}

@MainActor
final class FolderInviteRouter: ObservableObject {
    @Published var presented: FolderInviteLink?
    @Published private(set) var pending: FolderInviteLink?
    @Published var error: String?
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let value = defaults.string(forKey: "pendingFolderInvitation"), let url = URL(string: value) {
            pending = FolderInviteLink(url: url)
        }
    }
    func open(_ url: URL, signedIn: Bool) {
        guard url.scheme == "pictune" || url.host == FolderInviteLink.host else { return }
        guard let link = FolderInviteLink(url: url) else { error = FolderInviteError.invalidLink.localizedDescription; return }
        pending = link
        defaults.set(link.url.absoluteString, forKey: "pendingFolderInvitation")
        resume(signedIn: signedIn)
    }
    func resume(signedIn: Bool) { if signedIn { presented = pending } else { presented = nil } }
    func finish() { pending = nil; presented = nil; defaults.removeObject(forKey: "pendingFolderInvitation") }
}

@MainActor
final class SharedFolderModel: ObservableObject {
    @Published private(set) var folder: PhotoFolder?
    @Published private(set) var photos: [LibraryPhoto] = []
    @Published private(set) var error: String?
    @Published private(set) var isLoading = true
    private var imageTask: Task<Void, Never>?
    private var generation = UUID()
    private let repository: any FolderInvitationRepository
    private let photoLimit: Int?
    private let imageLoader: (LiveSharedFolder, PhotoRecord) async throws -> Data
    init(repository: any FolderInvitationRepository = FirebaseFolderInvitationRepository(),
         photoLimit: Int? = nil,
         imageLoader: @escaping (LiveSharedFolder, PhotoRecord) async throws -> Data = { folder, record in
             try await SharedImageAccess.load(folder: folder, photo: record)
         }) {
        self.repository = repository; self.photoLimit = photoLimit; self.imageLoader = imageLoader
    }
    func observe(_ reference: LiveSharedFolder) async {
        error = nil; isLoading = true
        defer { imageTask?.cancel() }
        do {
            for try await update in repository.observe(reference) {
                try Task.checkCancellation()
                switch update {
                case .folder(let folder): self.folder = folder; isLoading = false
                case .photos(let records):
                    let records = Array(records.prefix(photoLimit ?? records.count))
                    imageTask?.cancel()
                    let current = UUID(); generation = current
                    photos = photos.filter { photo in records.contains { $0.id == photo.id } }
                    imageTask = Task { [weak self] in
                        guard let self else { return }
                        var loaded: [LibraryPhoto] = []
                        for record in records {
                            do {
                                let data = try await imageLoader(reference, record)
                                try Task.checkCancellation()
                                if let image = UIImage(data: data) { loaded.append(LibraryPhoto(record: record, image: image)) }
                            } catch {
                                guard !Task.isCancelled else { return }
                                self.error = "一部の写真を読み込めませんでした。開き直すと再試行できます。"
                            }
                        }
                        guard !Task.isCancelled, generation == current else { return }
                        photos = loaded
                    }
                }
            }
        } catch {
            guard !Task.isCancelled else { return }
            folder = nil; photos = []; self.error = "共有が終了したか、接続できませんでした。\n\(error.localizedDescription)"; isLoading = false
        }
    }
}
