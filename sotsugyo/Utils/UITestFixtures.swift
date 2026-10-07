#if DEBUG
import SwiftUI

/// Deterministic, local-only data for simulator regression tests. Never used by release builds.
enum UITestFixtures {
    static var isEnabled: Bool { ProcessInfo.processInfo.arguments.contains("-ui-testing") }
    static var isSearch: Bool { ProcessInfo.processInfo.arguments.contains("-ui-testing-search") }
    static var isEditor: Bool { ProcessInfo.processInfo.arguments.contains("-ui-testing-editor") }
    static let letter = "楽しい思い出をありがとう。\nまた一緒に写真を撮りましょう。"

    static func image(_ alternate: Bool = false) -> UIImage {
        let size = CGSize(width: 333, height: 529)
        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            (alternate ? UIColor.systemTeal : UIColor.systemIndigo).setFill()
            context.fill(CGRect(x: 24, y: 51, width: 286, height: 386))
            UIColor.systemYellow.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 190, y: 85, width: 65, height: 65))
            UIColor.white.withAlphaComponent(0.7).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 45, y: 285, width: 230, height: 80))
        }
    }
}

struct UITestRootView: View {
    @StateObject private var photos = UITestContentModel()
    @StateObject private var folders = UITestContentModel()
    @StateObject private var camera = CameraManager()

    var body: some View {
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-invite") {
            FolderInvitationView(link: UITestInvitationRepository.link, repository: UITestInvitationRepository())
        } else if UITestFixtures.isSearch {
            UITestSearchView()
        } else if UITestFixtures.isEditor {
            PhotoPreviewView(images: UITestFixtures.image(), isPresentingCamera: .constant(true), cameraManager: camera, friendUid: .constant(""))
        } else {
            TabView {
                NavigationStack {
                    ContentView(viewModel: photos, cameraManager: camera, isPresentingCamera: $photos.isPresentingCamera)
                }
                .tabItem { Label("写真", systemImage: "photo.on.rectangle") }
                NavigationStack { FolderLibraryView(viewModel: folders) }
                    .tabItem { Label("フォルダ", systemImage: "folder") }
                NavigationStack {
                    SettingView(viewModel: UITestSettingViewModel(profile: UserProfile(name: "確認用ユーザー", email: "demo@example.com")))
                }
                .tabItem { Label("設定", systemImage: "gearshape") }
            }
        }
    }
}


private struct UITestSearchView: View {
    @State private var selectedTrack: Track?
    @StateObject private var viewModel: SearchViewModel

    init() {
        let defaults = UserDefaults(suiteName: "PicTune.UITests.Search")!
        defaults.removePersistentDomain(forName: "PicTune.UITests.Search")
        let model = SearchViewModel(defaults: defaults) { query in
            if query == "error" { throw URLError(.notConnectedToInternet) }
            if query == "empty" { return [] }
            return [Track(id: "fixture-track", name: "思い出の曲", artist: "PicTune Artist", albumImages: [], previewURL: nil, albumName: "卒業アルバム")]
        }
        let arguments = ProcessInfo.processInfo.arguments
        model.searchText = arguments.contains("-ui-testing-search-error") ? "error" : arguments.contains("-ui-testing-search-empty") ? "empty" : "思い出"
        _viewModel = StateObject(wrappedValue: model)
    }

    var body: some View {
        NavigationStack {
            SearchView(selectedTrack: $selectedTrack, viewModel: viewModel)
        }
    }
}

final class UITestContentModel: MainContentModel {
    private var fixtureLetter = UITestFixtures.letter

    override func loadPhotos(folderID: String) async throws {
        folderDocument = folderID
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH:mm"
        let music = FirebaseMusic(id: "fixture-music", artistName: "PicTune Artist", imageName: "", trackName: "思い出の曲", trackId: "fixture-track", previewURL: "")
        photos = [
            LibraryPhoto(record: PhotoRecord(id: "fixture-music", fileName: "fixture-music.jpg", date: formatter.date(from: "2024-03-01-12:30"), music: music, livePhotoFileName: ""), image: UITestFixtures.image()),
            LibraryPhoto(record: PhotoRecord(id: "fixture-photo-only", fileName: "fixture-photo-only.jpg", date: formatter.date(from: "2024-03-02-15:45"), music: nil, livePhotoFileName: ""), image: UITestFixtures.image(true))
        ]
    }

    override func getFolder() async throws {
        folders = [
            PhotoFolder(id: PhotoFolder.allID, title: "all", date: nil, letter: ""),
            PhotoFolder(id: "fixture-folder", title: "卒業の思い出", date: nil, letter: fixtureLetter)
        ]
        folderCoverImages = ["fixture-folder": UITestFixtures.image()]
    }

    override func loadFolderCover(folderId: String) async throws { }

    override func loadLetter(folderID: String) async throws -> String { fixtureLetter }
    @MainActor override func saveLetter(_ text: String, folderID: String) async throws { fixtureLetter = text }
    override func makeFolder(folderName: String) { }
    override func appendFolder(photoDocumentID: String, to destinationFolderID: String) async throws { }
    override func deletePhoto(document: String, folderId: String) async throws { }
    @MainActor override func deleteFolder(id: String) async throws { }
    override func getNFCData(NFCUid: String, NFCfolderid: String) async throws { }
    override func downloadFile(photo: LibraryPhoto) { }
}

@MainActor
final class UITestSettingViewModel: SettingViewModel {
    override func loadProfile() async throws { }
    override func saveName(name: String) async throws { }
    override func logout() { }
    override func deleteUser() { }
    override func reauthenticateWithPassword(password: String) { }
}
#endif

#if DEBUG
struct UITestInvitationRepository: FolderInvitationRepository {
    static let link = FolderInviteLink(token: String(repeating: "a", count: 64))
    static let shared = LiveSharedFolder(ownerID: "fixture-owner", folderID: "fixture-shared", title: "夏の旅行")
    func create(folderID: String) async throws -> FolderInvitation { try await resolve(link: Self.link) }
    func resolve(link: FolderInviteLink) async throws -> FolderInvitation {
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-invite-expired") { throw FolderInviteError.unavailable }
        return FolderInvitation(link: link, folder: Self.shared, senderName: "さき", expiresAt: Date().addingTimeInterval(604800), isRevoked: false)
    }
    func join(invitation: FolderInvitation) async throws -> LiveSharedFolder {
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-invite-offline") { throw URLError(.notConnectedToInternet) }
        try await Task.sleep(for: .milliseconds(350))
        return Self.shared
    }
    func revoke(link: FolderInviteLink) async throws { }
    func sharedFolders() async throws -> [LiveSharedFolder] { [Self.shared] }
    func observe(_ folder: LiveSharedFolder) -> AsyncThrowingStream<SharedFolderUpdate, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.folder(PhotoFolder(id: folder.folderID, title: folder.title, date: nil,
                letter: "旅行の写真をまとめたよ。\nまたみんなで行こうね！")))
            let photos = ProcessInfo.processInfo.arguments.contains("-ui-testing-invite-empty") ? [] : [PhotoRecord(id: "fixture", fileName: "fixture.jpg", date: Date(), music: nil, livePhotoFileName: "")]
            continuation.yield(.photos(photos))
            let update = Task {
                if ProcessInfo.processInfo.arguments.contains("-ui-testing-invite-update") {
                    try? await Task.sleep(for: .seconds(2))
                    guard !Task.isCancelled else { return }
                    continuation.yield(.folder(PhotoFolder(id: folder.folderID, title: folder.title, date: nil, letter: "旅行の写真を追加したよ。\nまたみんなで行こうね！")))
                }
            }
            continuation.onTermination = { _ in update.cancel() }
        }
    }
}
#endif
