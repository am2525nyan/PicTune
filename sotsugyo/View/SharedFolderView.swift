import SwiftUI

struct SharedFolderView: View {
    let reference: LiveSharedFolder
    @StateObject private var model: SharedFolderModel
    @State private var retryID = UUID()
    @Environment(\.scenePhase) private var scenePhase
    init(reference: LiveSharedFolder, repository: any FolderInvitationRepository = FirebaseFolderInvitationRepository()) {
        self.reference = reference
        #if DEBUG
        if UITestFixtures.isEnabled {
            _model = StateObject(wrappedValue: SharedFolderModel(repository: repository, imageLoader: { _, _ in UITestFixtures.image().pngData()! }))
        } else {
            _model = StateObject(wrappedValue: SharedFolderModel(repository: repository))
        }
        #else
        _model = StateObject(wrappedValue: SharedFolderModel(repository: repository))
        #endif
    }
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Label("共有中・閲覧のみ", systemImage: "person.2.fill")
                    .font(.caption.bold()).foregroundStyle(.purple)
                Text(model.folder?.title ?? reference.title).font(.largeTitle.bold()).multilineTextAlignment(.center)
                if let error = model.error {
                    Text(error).font(.subheadline).multilineTextAlignment(.center)
                    Button("再読み込み") { retryID = UUID() }
                }
                if model.isLoading { ProgressView("フォルダを読み込んでいます…") }
                if let folder = model.folder, !folder.letter.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("手紙", systemImage: "envelope.open").font(.headline).foregroundStyle(.purple)
                        Text(folder.letter).font(.body).lineSpacing(8).frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("shared.letter")
                    }
                    .padding(24).background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
                }
                ForEach(model.photos) { photo in
                    VStack(spacing: 0) {
                        Image(uiImage: photo.image).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 16))
                        if let music = photo.record.music { MusicAttachmentView(track: music.track) }
                    }
                    .padding(12).background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
                }
                if model.folder != nil && model.photos.isEmpty && !model.isLoading {
                    Text("写真は、送り主が追加するとここに届きます。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }.padding(24).frame(maxWidth: 560).frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("共有されたフォルダ").navigationBarTitleDisplayMode(.inline)
        .task(id: "\(retryID)-\(scenePhase == .active)") {
            if scenePhase == .active { await model.observe(reference) }
        }
    }
}

struct SharedFolderLibrarySection: View {
    @State private var folders: [LiveSharedFolder] = []
    @State private var error: String?
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !folders.isEmpty {
                Text("共有されたフォルダ").font(.title2.bold())
                ForEach(folders) { folder in
                    NavigationLink {
                        SharedFolderView(reference: folder)
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "envelope.open.fill").font(.title2).foregroundStyle(.purple)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(folder.title).font(.headline)
                                Text("相手の更新も反映されます").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.secondary)
                        }.padding().background(.purple.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
                    }.buttonStyle(.plain)
                }
            }
            if let error { Text(error).font(.footnote).foregroundStyle(.secondary) }
        }
        .task(id: scenePhase == .active) {
            guard scenePhase == .active else { return }
            #if DEBUG
            if UITestFixtures.isEnabled { return }
            #endif
            do {
                for try await updated in FirebaseFolderInvitationRepository().observeLibrary() {
                    try Task.checkCancellation()
                    folders = updated; error = nil
                }
            }
            catch { if !Task.isCancelled { self.error = "共有されたフォルダを読み込めませんでした。" } }
        }
    }
}
