import SwiftUI

struct ImageDetailView: View {
    let photo: LibraryPhoto
    @ObservedObject var viewModel: MainContentModel
    @State private var isDownload = false

    var body: some View {
        ZStack{
            Color(red: 229 / 255, green: 217 / 255, blue: 255 / 255, opacity: 1.0)
                .edgesIgnoringSafeArea(.all)
            VStack {
                VStack {
                    VStack{
                        if photo.record.date != nil {
                            Text("日付: \(photo.dateText)")
                                .padding()
                        } else {
                            Text("日付情報なし")
                                .padding()
                        }
                    }
                    .frame(width: 333, height: 40)
                    .background(Color.white)
                    ZStack{

                        Group {
                            let unwrappedImage = photo.image
                            Image(uiImage: unwrappedImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 333)
                                .navigationBarTitle("画像詳細", displayMode: .inline)
                                .navigationBarItems(
                                    trailing: HStack{
                                        Button (action: {
                                            viewModel.downloadFile(photo: photo)
                                            isDownload.toggle()
                                        } , label: {
                                            Image(systemName: "square.and.arrow.down")
                                        })
                                        .alert(isPresented: $isDownload) {
                                            Alert(
                                                title: Text("保存"),
                                                message: Text("カメラロールに保存しました！"),
                                                dismissButton: .default(Text("OK")))
                                        }

                                        ShareLink(item: unwrappedImage, preview: SharePreview("チェキ", image: unwrappedImage))

                                    }
                                )
                        }
                    }

                }

                VStack {

                    if let music = photo.record.music {

                        HStack {
                            AsyncImage(url: URL(string: music.imageName)) { phase in
                                switch phase {
                                case .empty:
                                    Image(systemName: "photo")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 100, height: 100)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 100, height: 100)
                                case .failure:
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(.red)
                                        .frame(width: 100, height: 100)
                                @unknown default:
                                    Image(systemName: "photo")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 100, height: 100)
                                }
                            }
                            .padding(10)
                            VStack {
                                Text(music.trackName)
                                    .font(.headline)
                                    .padding(.top, 8)

                                Text(music.artistName)
                                    .font(.subheadline)
                                    .padding(.top, 4)

                            }
                            .padding(EdgeInsets(
                                top: 10,
                                leading: 27,
                                bottom: 10,
                                trailing: 27
                            ))

                        }

                    } else {
                        Label("音楽なし", systemImage: "music.note")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding()
                    }

                }

                .frame(width: 333)

                .onDisappear{
                    viewModel.stop()
                }

                .background(Color.white)
                .onTapGesture {
                    viewModel.startPlay(music: photo.record.music)
                }

            }

        }

    }
}
extension UIImage: Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.image)
    }

    var image: Image {
        Image(uiImage: self)
    }
}
