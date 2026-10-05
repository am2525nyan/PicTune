import SwiftUI

struct FolderContentView: View {
    @ObservedObject var viewModel: MainContentModel
    @Binding var selectedFolderIndex: Int
    @State private var pendingDeletion: FolderItem?
    @State private var isConfirmingDeletion = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    private struct FolderItem: Identifiable {
        let id: String
        let name: String
    }

    private var folderItems: [FolderItem] {
        zip(viewModel.foldersDocumentId, viewModel.folders).map {
            FolderItem(id: $0.0, name: $0.1)
        }
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(folderItems) { folder in
                    Button {
                        guard let index = viewModel.foldersDocumentId.firstIndex(of: folder.id) else { return }
                        selectedFolderIndex = index
                        viewModel.folderDocument = folder.id
                        viewModel.getimage.toggle()
                    } label: {
                        Text(folder.name)
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .tint(viewModel.folderDocument == folder.id ? .accentColor : .secondary)
                    .accessibilityAddTraits(viewModel.folderDocument == folder.id ? .isSelected : [])
                    .contextMenu {
                        if folder.id != "all" {
                            Button("フォルダを削除", systemImage: "trash", role: .destructive) {
                                pendingDeletion = folder
                                isConfirmingDeletion = true
                            }
                        }
                    }
                    .accessibilityActions {
                        if folder.id != "all" {
                            Button("フォルダを削除", role: .destructive) {
                                pendingDeletion = folder
                                isConfirmingDeletion = true
                            }
                        }
                    }
                }
            }
        }
        .disabled(isDeleting)
        .overlay {
            if isDeleting { ProgressView("削除中…").padding().background(.regularMaterial) }
        }
        .confirmationDialog("「\(pendingDeletion?.name ?? "")」を削除しますか？", isPresented: $isConfirmingDeletion, titleVisibility: .visible) {
            Button("フォルダを削除", role: .destructive) { deleteFolder() }
            Button("キャンセル", role: .cancel) { pendingDeletion = nil }
        } message: {
            Text("フォルダと手紙を削除します。「all」の写真は削除されません。この操作は取り消せません。")
        }
        .alert("フォルダを削除できませんでした", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func deleteFolder() {
        guard let folder = pendingDeletion else { return }
        isDeleting = true
        Task { @MainActor in
            defer { isDeleting = false; pendingDeletion = nil }
            do {
                try await viewModel.deleteFolder(id: folder.id)
                selectedFolderIndex = viewModel.foldersDocumentId.firstIndex(of: viewModel.folderDocument) ?? 0
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
