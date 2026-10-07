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
    @State private var isPresentingMusicStep = false
    @State private var isPresentingSearch = false
    @State private var isConfirmingDiscard = false
    @State private var isShowingSaveResult = false

    private enum EditingTool: String, CaseIterable {
        case stamp = "スタンプ"
        case pencil = "ペン"
    }

    var body: some View {
        NavigationStack {
            Group {
                if let image = images {
                    GeometryReader { geometry in
                        ZoomablePhotoEditor(image: image, stamp: selectedStamp, canvas: canvas,
                                            isDrawing: tool == .pencil, viewportSize: geometry.size)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                    .safeAreaInset(edge: .top, spacing: 0) { toolSelection }
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        if tool == .stamp { stampSelection }
                    }
                } else {
                    ContentUnavailableView("写真がありません", systemImage: "photo")
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
                    Button("次へ") { isPresentingMusicStep = true }
                        .fontWeight(.semibold)
                        .disabled(images == nil)
                }
            }
            .navigationDestination(isPresented: $isPresentingMusicStep) {
                musicStep
            }
            .confirmationDialog("編集を終了しますか？", isPresented: $isConfirmingDiscard, titleVisibility: .visible) {
                Button("編集を破棄", role: .destructive) { dismiss() }
                Button("編集を続ける", role: .cancel) { }
            } message: {
                Text("この画面での編集内容は保存されません。")
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
        .interactiveDismissDisabled()
    }

    private var toolSelection: some View {
        VStack(spacing: 8) {
            Picker("編集ツール", selection: $tool) {
                ForEach(EditingTool.allCases, id: \.self) { tool in
                    Text(tool.rawValue).tag(tool)
                }
            }
            .pickerStyle(.segmented)

            if tool == .pencil {
                Text("指やApple Pencilで描けます。2本の指で拡大・縮小できます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }

    private var stampSelection: some View {
        stampPicker
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.regularMaterial)
    }

    private var musicStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let image = images {
                    PhotoArtwork(image: image, stamp: selectedStamp)
                        .overlay {
                            Image(uiImage: canvas.drawing.image(from: CGRect(origin: .zero, size: PhotoArtwork.size), scale: 3))
                                .resizable()
                        }
                        .frame(width: PhotoArtwork.size.width, height: PhotoArtwork.size.height)
                        .scaleEffect(200 / PhotoArtwork.size.width, anchor: .topLeading)
                        .frame(width: 200, height: 200 * PhotoArtwork.size.height / PhotoArtwork.size.width,
                               alignment: .topLeading)
                        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                        .accessibilityLabel("編集した写真のプレビュー")
                }
                musicSelection
            }
            .padding()
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("音楽を追加")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { save() }
                    .fontWeight(.semibold)
                    .disabled(viewModel.isSaving)
            }
        }
        .navigationDestination(isPresented: $isPresentingSearch) {
            SearchView(selectedTrack: $selectedTrack)
        }
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

private struct ZoomablePhotoEditor: UIViewRepresentable {
    let image: UIImage
    let stamp: String?
    let canvas: PKCanvasView
    let isDrawing: Bool
    let viewportSize: CGSize

    class Coordinator: NSObject, UIScrollViewDelegate {
        let picker = PKToolPicker()
        var artwork: UIHostingController<PhotoArtwork>?
        var content = UIView(frame: CGRect(origin: .zero, size: PhotoArtwork.size))
        var fittedScale: CGFloat = 0

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { content }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerContent(in: scrollView, size: scrollView.bounds.size)
        }

        func centerContent(in scrollView: UIScrollView, size: CGSize) {
            scrollView.contentInset = UIEdgeInsets(
                top: max(0, (size.height - content.frame.height) / 2),
                left: max(0, (size.width - content.frame.width) / 2),
                bottom: 0, right: 0)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.accessibilityIdentifier = "photo.editor.canvas"
        scrollView.delegate = context.coordinator
        scrollView.backgroundColor = .systemGroupedBackground
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.panGestureRecognizer.minimumNumberOfTouches = 2

        let artwork = UIHostingController(rootView: PhotoArtwork(image: image, stamp: stamp))
        artwork.view.frame = context.coordinator.content.bounds
        artwork.view.backgroundColor = .clear
        artwork.view.isUserInteractionEnabled = false
        context.coordinator.artwork = artwork
        context.coordinator.content.addSubview(artwork.view)

        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = .anyInput
        canvas.isScrollEnabled = false
        canvas.frame = context.coordinator.content.bounds
        context.coordinator.content.addSubview(canvas)
        scrollView.addSubview(context.coordinator.content)
        scrollView.contentSize = PhotoArtwork.size
        context.coordinator.picker.addObserver(canvas)
        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.artwork?.rootView = PhotoArtwork(image: image, stamp: stamp)
        if viewportSize.width > 0 && viewportSize.height > 0 {
            let fittedScale = min(viewportSize.width / PhotoArtwork.size.width,
                                  viewportSize.height / PhotoArtwork.size.height)
            if abs(context.coordinator.fittedScale - fittedScale) > 0.001 {
                let wasAtFit = context.coordinator.fittedScale == 0 ||
                    scrollView.zoomScale <= context.coordinator.fittedScale + 0.001
                context.coordinator.fittedScale = fittedScale
                scrollView.minimumZoomScale = fittedScale
                scrollView.maximumZoomScale = fittedScale * 4
                if wasAtFit { scrollView.zoomScale = fittedScale }
            }
            context.coordinator.centerContent(in: scrollView, size: viewportSize)
        }
        canvas.isUserInteractionEnabled = isDrawing
        context.coordinator.picker.setVisible(isDrawing, forFirstResponder: canvas)
        if isDrawing {
            canvas.becomeFirstResponder()
        } else {
            canvas.resignFirstResponder()
        }
    }

    static func dismantleUIView(_ scrollView: UIScrollView, coordinator: Coordinator) {
        if let canvas = coordinator.content.subviews.compactMap({ $0 as? PKCanvasView }).first {
            coordinator.picker.setVisible(false, forFirstResponder: canvas)
            coordinator.picker.removeObserver(canvas)
            canvas.resignFirstResponder()
            canvas.removeFromSuperview()
        }
    }
}
