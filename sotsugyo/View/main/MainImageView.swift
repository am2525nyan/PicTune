import SwiftUI

struct MainImageView: View {
    @ObservedObject var viewModel: MainContentModel
    let folderId: String

    private struct DisplayPhoto: Identifiable {
        let id: String
        let image: UIImage
        let position: Int
    }

    private var photos: [DisplayPhoto] {
        let count = min(viewModel.images.count, viewModel.documentIdArray.count)
        return (0..<count).map { index in
            DisplayPhoto(id: viewModel.documentIdArray[index], image: viewModel.images[index], position: index)
        }
    }

    private let columns = [GridItem(.adaptive(minimum: 160, maximum: 260), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(photos) { photo in
                photoCell(photo)
            }
        }
        .padding(.vertical, 8)
    }

    private func photoCell(_ photo: DisplayPhoto) -> some View {
        return NavigationLink {
            ImageDetailView(
                image: photo.image,
                documentId: photo.id,
                folderId: folderId
            )
        } label: {
            Image(uiImage: photo.image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
        }
        .accessibilityLabel("チェキ \(photo.position + 1)")
        .contextMenu {
            if folderId == "all" {
                Menu("フォルダに追加") {
                    ForEach(viewModel.foldersDocumentId.indices, id: \.self) { folderIndex in
                        if viewModel.folders.indices.contains(folderIndex),
                           viewModel.foldersDocumentId[folderIndex] != "all" {
                            Button(viewModel.folders[folderIndex]) {
                                Task {
                                    try? await viewModel.appendFolder(
                                        photoDocumentID: photo.id,
                                        to: viewModel.foldersDocumentId[folderIndex]
                                    )
                                }
                            }
                        }
                    }
                }
            }

            Button("削除", role: .destructive) {
                Task {
                    do {
                        try await viewModel.deletePhoto(document: photo.id, folderId: folderId)
                        await reloadPhotos()
                    } catch {
                        print("写真の削除に失敗しました: \(error)")
                    }
                }
            }
        }
    }

    private func reloadPhotos() async {
        if folderId == "all" {
            try? await viewModel.firstgetUrl()
            try? await viewModel.getDate()
        } else if let folderIndex = viewModel.foldersDocumentId.firstIndex(of: folderId) {
            try? await viewModel.FoldergetUrl(folderId: folderIndex)
        }
    }
}
