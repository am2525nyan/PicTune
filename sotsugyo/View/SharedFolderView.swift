import SwiftUI

struct SharedFolderView: View {
    let reference: LiveSharedFolder
    let senderName: String?
    @StateObject private var model: SharedFolderModel
    @State private var retryID = UUID()
    @Environment(\.scenePhase) private var scenePhase
    init(reference: LiveSharedFolder, senderName: String? = nil, repository: any FolderInvitationRepository = FirebaseFolderInvitationRepository()) {
        self.reference = reference
        self.senderName = senderName
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
            VStack(alignment: .leading, spacing: 28) {
                VStack(spacing: 12) {
                    if let senderName {
                        Text("\(senderName)さんから").font(.subheadline.bold()).foregroundStyle(.secondary)
                    }
                    Text(model.folder?.title ?? reference.title)
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(.top, 12)
                if let error = model.error {
                    Text(error).font(.subheadline).multilineTextAlignment(.center)
                    Button("再読み込み") { retryID = UUID() }
                }
                if model.isLoading { ProgressView("フォルダを読み込んでいます…") }
                if let folder = model.folder, !folder.letter.isEmpty {
                    VStack(alignment: .leading, spacing: 20) {
                        Label("手紙", systemImage: "envelope.open")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(GiftPalette.purpleText)
                        Rectangle().fill(.purple.opacity(0.12)).frame(height: 1)
                        Text(folder.letter).font(.body).lineSpacing(8).frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("shared.letter")
                    }
                    .padding(24).padding(.top, 8)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(alignment: .top) {
                        Rectangle().fill(Color(red: 0.96, green: 0.76, blue: 0.85).opacity(0.8))
                            .frame(width: 66, height: 18).rotationEffect(.degrees(-4)).offset(y: -8)
                            .accessibilityHidden(true)
                    }
                    .padding(.top, 12)
                }
                if !model.photos.isEmpty {
                    Text("チェキ").font(.system(.title3, design: .rounded, weight: .bold))
                }
                ForEach(model.photos) { photo in
                    VStack(spacing: 0) {
                        Image(uiImage: photo.image).resizable().scaledToFit()
                        if let music = photo.record.music { MusicAttachmentView(track: music.track) }
                    }
                    .padding(8).background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 6))
                    .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
                }
                if model.folder != nil && model.photos.isEmpty && !model.isLoading {
                    Text("写真は、送り主が追加するとここに届きます。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if model.folder != nil {
                    Text("相手の更新もここに反映されます。内容の編集はできません。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.padding(24).frame(maxWidth: 560).frame(maxWidth: .infinity)
        }
        .background { GiftBackdrop() }
        .navigationTitle("届いた思い出").navigationBarTitleDisplayMode(.inline)
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
                Text("届いた思い出").font(.title2.bold())
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
