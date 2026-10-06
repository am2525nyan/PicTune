import SwiftUI

struct MainImageView: View {
    @ObservedObject var viewModel: MainContentModel
    let folderId: String

    private let columns = [GridItem(.adaptive(minimum: 160, maximum: 260), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(Array(viewModel.photos.enumerated()), id: \.element.id) { position, photo in
                photoCell(photo, position: position)
            }
        }
        .padding(.vertical, 8)
    }

    private func photoCell(_ photo: LibraryPhoto, position: Int) -> some View {
        return NavigationLink {
            ImageDetailView(photo: photo)
        } label: {
            Image(uiImage: photo.image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
        }
        .accessibilityLabel("チェキ \(position + 1)")
        .contextMenu {
            if folderId == "all" {
                Menu("フォルダに追加") {
                    ForEach(viewModel.folders.filter { $0.id != PhotoFolder.allID }) { folder in
                        Button(folder.title) {
                            Task {
                                try? await viewModel.appendFolder(photoDocumentID: photo.id, to: folder.id)
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
        try? await viewModel.loadPhotos(folderID: folderId)
    }
}
