import SwiftUI
import PencilKit

struct PhotoPreviewView: View {
    var images: UIImage?
    @Binding var isPresentingCamera: Bool
    @ObservedObject var cameraManager: CameraManager
    @Binding var friendUid: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = PhotoPreviewViewModel()
    @State private var canvas = PKCanvasView()
    @State private var selectedStamp: String?
    @State private var selectedTrack: Track?
    @State private var tool: EditingTool = .stamp
    @State private var isPresentingSearch = false
    @State private var isConfirmingDiscard = false
    @State private var isShowingSaveResult = false

    private enum EditingTool: String, CaseIterable {
        case stamp = "スタンプ"
        case pencil = "ペン"
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 16) {
                        if let image = images {
                            photoEditor(image)
                                .frame(maxWidth: min(333, geometry.size.height * 0.42 * PhotoArtwork.size.width / PhotoArtwork.size.height))
                            Picker("編集ツール", selection: $tool) {
                                ForEach(EditingTool.allCases, id: \.self) { tool in
                                    Text(tool.rawValue).tag(tool)
                                }
                            }
                            .pickerStyle(.segmented)

                            if tool == .stamp {
                                stampPicker
                            } else {
                                Text("写真に指やApple Pencilで描けます。")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            musicSelection
                        } else {
                            ContentUnavailableView("写真がありません", systemImage: "photo")
                        }
                    }
                    .padding()
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("写真を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる", systemImage: "xmark") {
                        isConfirmingDiscard = true
                    }
                    .disabled(viewModel.isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .fontWeight(.semibold)
                        .buttonStyle(.borderedProminent)
                        .disabled(images == nil || viewModel.isSaving)
                }
            }
            .disabled(viewModel.isSaving)
            .overlay {
                if viewModel.isSaving {
                    ProgressView("保存中…")
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .navigationDestination(isPresented: $isPresentingSearch) {
                SearchView(selectedTrack: $selectedTrack)
            }
            .confirmationDialog("編集を終了しますか？", isPresented: $isConfirmingDiscard, titleVisibility: .visible) {
                Button("編集を破棄", role: .destructive) { dismiss() }
                Button("編集を続ける", role: .cancel) { }
            } message: {
                Text("この画面での編集内容は保存されません。")
            }
            .alert("保存できませんでした", isPresented: $viewModel.isShowingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
            .alert("保存しました", isPresented: $isShowingSaveResult) {
                Button("完了") {
                    dismiss()
                    isPresentingCamera = false
                }
            } message: {
                Text(viewModel.saveMessage)
            }
        }
        .interactiveDismissDisabled()
    }

    private func photoEditor(_ image: UIImage) -> some View {
        GeometryReader { geometry in
            let scale = geometry.size.width / PhotoArtwork.size.width
            ZStack {
                PhotoArtwork(image: image, stamp: selectedStamp)
                PhotoDrawingCanvas(canvas: canvas, isEnabled: tool == .pencil && !viewModel.isSaving && !isPresentingSearch)
            }
            .frame(width: PhotoArtwork.size.width, height: PhotoArtwork.size.height)
            .clipped()
            .scaleEffect(scale, anchor: .topLeading)
        }
        .aspectRatio(PhotoArtwork.size, contentMode: .fit)
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        .accessibilityLabel("撮影した写真の編集プレビュー")
    }

    private var stampPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                Button {
                    selectedStamp = nil
                } label: {
                    VStack {
                        Image(systemName: "nosign").font(.title2)
                        Text("なし").font(.caption)
                    }
                    .frame(width: 64, height: 96)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8).strokeBorder(selectedStamp == nil ? Color.accentColor : .clear, lineWidth: 3)
                    }
                }
                .accessibilityAddTraits(selectedStamp == nil ? .isSelected : [])
                ForEach(1..<17) { index in
                    Button {
                        selectedStamp = String(index)
                    } label: {
                        Image(String(index))
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64, height: 96)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8).strokeBorder(selectedStamp == String(index) ? Color.accentColor : .clear, lineWidth: 3)
                            }
                    }
                    .accessibilityLabel("スタンプ\(index)")
                    .accessibilityAddTraits(selectedStamp == String(index) ? .isSelected : [])
                }
            }
            .padding(3)
        }
        .buttonStyle(.plain)
        .scrollIndicators(.hidden)
    }

    private var musicSelection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("音楽").font(.headline)
                Text("任意").font(.subheadline).foregroundStyle(.secondary)
            }
            if let track = selectedTrack {
                HStack {
                    Button {
                        isPresentingSearch = true
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(track.name).font(.body)
                            Text(track.artist).font(.subheadline).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    .accessibilityHint("選択した音楽を変更します")
                    Button("音楽を削除", systemImage: "xmark.circle.fill", role: .destructive) {
                        selectedTrack = nil
                    }
                    .labelStyle(.iconOnly)
                    .frame(minWidth: 44, minHeight: 44)
                }
            } else {
                Button {
                    isPresentingSearch = true
                } label: {
                    Label("音楽を追加", systemImage: "music.note")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                Text("音楽を追加せずに写真だけでも保存できます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func save() {
        guard let image = images, !viewModel.isSaving else { return }
        canvas.resignFirstResponder()
        Task { @MainActor in
            if await viewModel.save(image: image, stamp: selectedStamp, drawing: canvas.drawing,
                                    track: selectedTrack, cameraManager: cameraManager, friendUid: friendUid) {
                isShowingSaveResult = true
            }
        }
    }
}

// The preview and exported image share one coordinate system, independent of screen size.
struct PhotoArtwork: View {
    static let size = CGSize(width: 333, height: 529)
    let image: UIImage
    let stamp: String?

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image("Image").resizable().frame(width: Self.size.width, height: Self.size.height)
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 286, height: 386)
                .clipped()
                .offset(x: 24, y: 51)
            if let stamp {
                Image(stamp).resizable().frame(width: Self.size.width, height: Self.size.height)
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }
}

private struct PhotoDrawingCanvas: UIViewRepresentable {
    let canvas: PKCanvasView
    let isEnabled: Bool

    class Coordinator {
        let picker = PKToolPicker()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PKCanvasView {
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = .anyInput
        canvas.isScrollEnabled = false
        context.coordinator.picker.addObserver(canvas)
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.isUserInteractionEnabled = isEnabled
        context.coordinator.picker.setVisible(isEnabled, forFirstResponder: uiView)
        if isEnabled {
            uiView.becomeFirstResponder()
        } else {
            uiView.resignFirstResponder()
        }
    }

    static func dismantleUIView(_ uiView: PKCanvasView, coordinator: Coordinator) {
        coordinator.picker.setVisible(false, forFirstResponder: uiView)
        coordinator.picker.removeObserver(uiView)
        uiView.resignFirstResponder()
    }
}
