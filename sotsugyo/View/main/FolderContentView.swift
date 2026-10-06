import SwiftUI
import FirebaseAuth
import CoreNFC

struct FolderLibraryView: View {
    @ObservedObject var viewModel: MainContentModel
    @StateObject private var nfcSession = NFCSession()
    @State private var isLoading = true
    @State private var isShowingCreateFolder = false
    @State private var isShowingNFCResult = false
    @State private var nfcResultMessage = ""
    @State private var folderName = ""
    @State private var pendingDeletion: PhotoFolder?
    @State private var isConfirmingDeletion = false
    @State private var isDeleting = false
    @State private var errorMessage: String?
    private let columns = [GridItem(.adaptive(minimum: 160, maximum: 240), spacing: 16)]

    private var folders: [PhotoFolder] {
        viewModel.folders.filter { $0.id != PhotoFolder.allID }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if folders.isEmpty {
                ContentUnavailableView(
                    "フォルダがありません",
                    systemImage: "folder",
                    description: Text("作成したフォルダがここに表示されます")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 24) {
                        ForEach(folders) { folder in
                            NavigationLink {
                                FolderDetailView(viewModel: viewModel, folderId: folder.id, folderName: folder.title)
                            } label: {
                                FolderLibraryCard(viewModel: viewModel, folderId: folder.id, folderName: folder.title)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("フォルダを削除", systemImage: "trash", role: .destructive) {
                                    pendingDeletion = folder
                                    isConfirmingDeletion = true
                                }
                            }
                            .accessibilityActions {
                                Button("フォルダを削除", role: .destructive) {
                                    pendingDeletion = folder
                                    isConfirmingDeletion = true
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
                .refreshable { await reloadFolders() }
            }
        }
        .disabled(isDeleting)
        .overlay {
            if isDeleting { ProgressView("削除中…").padding().background(.regularMaterial) }
        }
        .confirmationDialog("「\(pendingDeletion?.title ?? "")」を削除しますか？", isPresented: $isConfirmingDeletion, titleVisibility: .visible) {
            Button("フォルダを削除", role: .destructive) { deleteFolder() }
            Button("キャンセル", role: .cancel) { pendingDeletion = nil }
        } message: {
            Text("フォルダと手紙を削除します。写真タブの写真は削除されません。この操作は取り消せません。")
        }
        .alert("フォルダの操作に失敗しました", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .navigationTitle("フォルダ")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    startNFCReadSession()
                } label: {
                    Label("NFCを読み込む", systemImage: "wave.3.right")
                }
                .labelStyle(.iconOnly)
                .accessibilityLabel("NFCを読み込む")
            }
            if #available(iOS 26.0, *) {
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingCreateFolder = true
                } label: {
                    Label("フォルダを作成", systemImage: "folder.badge.plus")
                }
                .labelStyle(.iconOnly)
                .accessibilityLabel("フォルダを作成")
                .disabled(isLoading)
            }
        }
        .alert("フォルダを作成", isPresented: $isShowingCreateFolder) {
            TextField("フォルダ名", text: $folderName)
            Button("キャンセル", role: .cancel) {
                folderName = ""
            }
            Button("作成") {
                let name = folderName
                Task {
                    do { try await viewModel.makeFolder(folderName: name) }
                    catch { errorMessage = error.localizedDescription }
                }
                folderName = ""
            }
            .disabled(folderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("新しいフォルダの名前を入力してください。")
        }
        .alert("NFC読み込み", isPresented: $isShowingNFCResult) {
            Button("閉じる", role: .cancel) { }
        } message: {
            Text(nfcResultMessage)
        }
        .onAppear {
            Task { await reloadFolders() }
        }
    }

    private func deleteFolder() {
        guard let folder = pendingDeletion else { return }
        isDeleting = true
        Task { @MainActor in
            defer { isDeleting = false; pendingDeletion = nil }
            do {
                try await viewModel.deleteFolder(id: folder.id)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func startNFCReadSession() {
        guard NFCNDEFReaderSession.readingAvailable else {
            showNFCResult("このデバイスではNFCを読み込めません。")
            return
        }

        nfcSession.startReadSession { _, payload, error in
            if let error {
                showNFCResult(error.localizedDescription)
                return
            }

            guard let payload, let reference = SharedFolderReference(payload: payload) else {
                showNFCResult("フォルダの情報を読み取れませんでした。")
                return
            }

            Task {
                do {
                    try await viewModel.getNFCData(NFCUid: reference.userID, NFCfolderid: reference.folderID)
                    await reloadFolders()
                    showNFCResult("フォルダを読み込みました。")
                } catch {
                    showNFCResult(error.localizedDescription)
                }
            }
        }
    }

    private func showNFCResult(_ message: String) {
        nfcResultMessage = message
        isShowingNFCResult = true
    }

    private func reloadFolders() async {
        do {
            try await viewModel.getFolder()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct FolderLibraryCard: View {
    @ObservedObject var viewModel: MainContentModel
    let folderId: String
    let folderName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FolderCover(image: viewModel.folderCoverImages[folderId])
            Text(folderName)
                .font(.headline)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .task(id: folderId) {
            try? await viewModel.loadFolderCover(folderId: folderId)
        }
    }
}

private struct FolderCover: View {
    let image: UIImage?
    var size: CGFloat? = nil

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.purple.opacity(0.15)
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else {
                    Image(systemName: "folder.fill")
                        .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.4))
                        .foregroundStyle(.purple)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityHidden(true)
    }
}

struct FolderDetailView: View {
    @ObservedObject var viewModel: MainContentModel
    let folderId: String
    let folderName: String

    @StateObject private var color = ColorModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var errorMessage = ""
    @State private var showError = false

    var body: some View {
        ZStack {
            color.backGroundColor().ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    FolderCover(image: viewModel.folderCoverImages[folderId], size: 150)
                        .padding(.top, 16)

                    VStack(spacing: 4) {
                        Text(folderName)
                            .font(.title.bold())
                            .multilineTextAlignment(.center)
                        Text("\(viewModel.photos.count)枚のチェキ")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    FolderTextView(viewModel: viewModel, folderDocument: .constant(folderId))

                    MainImageView(viewModel: viewModel, folderId: folderId)
                }
                .padding(.horizontal, 16)
            }
            .refreshable { await reloadPhotos() }
        }
        .navigationTitle(folderName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("フォルダを削除", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("その他")
            }
        }
        .confirmationDialog("フォルダを削除しますか？", isPresented: $showDeleteConfirmation) {
            Button("フォルダを削除", role: .destructive) {
                Task {
                    do {
                        try await viewModel.deleteFolder(id: folderId)
                        await MainActor.run { dismiss() }
                    } catch {
                        await MainActor.run { show(error) }
                    }
                }
            }
        }
        .alert("エラー", isPresented: $showError) {
            Button("閉じる", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .task(id: folderId) {
            await reloadPhotos()
            try? await viewModel.loadFolderCover(folderId: folderId)
        }
    }

    private func reloadPhotos() async {
        do {
            try await viewModel.loadPhotos(folderID: folderId)
        } catch {
            await MainActor.run { show(error) }
        }
    }

    private func show(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }
}
