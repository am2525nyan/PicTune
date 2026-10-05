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
    private let columns = [GridItem(.adaptive(minimum: 160, maximum: 240), spacing: 16)]

    private struct FolderEntry: Identifiable {
        let id: String
        let name: String
    }

    private var folders: [FolderEntry] {
        zip(viewModel.foldersDocumentId, viewModel.folders)
            .filter { $0.0 != "all" }
            .map { FolderEntry(id: $0.0, name: $0.1) }
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
                                FolderDetailView(viewModel: viewModel, folderId: folder.id, folderName: folder.name)
                            } label: {
                                FolderLibraryCard(viewModel: viewModel, folderId: folder.id, folderName: folder.name)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
                .refreshable { await reloadFolders() }
            }
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
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
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
                viewModel.makeFolder(folderName: folderName.trimmingCharacters(in: .whitespacesAndNewlines))
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

            let parts = payload?.split(separator: " ", maxSplits: 1).map(String.init) ?? []
            guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else {
                showNFCResult("フォルダの情報を読み取れませんでした。")
                return
            }

            Task {
                do {
                    try await viewModel.getNFCData(NFCUid: parts[0], NFCfolderid: parts[1])
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
            print("フォルダの読み込みに失敗しました: \(error)")
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
    @StateObject private var session = NFCSession()
    @Environment(\.dismiss) private var dismiss
    @State private var isWritingLetter = false
    @State private var showNFCConfirmation = false
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
                        Text("\(viewModel.images.count)枚のチェキ")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 12) {
                        Button {
                            viewModel.folderDocument = folderId
                            viewModel.getLetter()
                            isWritingLetter = true
                        } label: {
                            Label("手紙", systemImage: "envelope")
                                .frame(maxWidth: .infinity)
                        }
                        .accessibilityLabel("手紙を見る・書く")

                        Button {
                            showNFCConfirmation = true
                        } label: {
                            Text("NFCに保存")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.bordered)

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
        .sheet(isPresented: $isWritingLetter) {
            WriteLetterView(isWrite: $isWritingLetter, viewModel: viewModel, userDataList: viewModel)
        }
        .confirmationDialog("このフォルダをNFCカードに保存しますか？", isPresented: $showNFCConfirmation) {
            Button("NFCに保存") { writeToNFC() }
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
        guard let index = viewModel.foldersDocumentId.firstIndex(of: folderId) else { return }
        do {
            try await viewModel.FoldergetUrl(folderId: index)
        } catch {
            await MainActor.run { show(error) }
        }
    }

    private func writeToNFC() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        session.startWriteSession(UserUid: uid, folder: folderId) { error in
            if let error {
                DispatchQueue.main.async { show(error) }
            }
        }
    }

    private func show(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }
}
