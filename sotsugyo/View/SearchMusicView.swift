import SwiftUI

struct SearchView: View {
    @Binding var selectedTrack: Track?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel: SearchViewModel
    @State private var retryCount = 0
    @State private var isConfirmingClearHistory = false

    init(selectedTrack: Binding<Track?>, viewModel: SearchViewModel? = nil) {
        _selectedTrack = selectedTrack
        _viewModel = StateObject(wrappedValue: viewModel ?? SearchViewModel(selection: selectedTrack.wrappedValue))
    }

    private struct SearchRequest: Equatable {
        let query: String
        let retryCount: Int
    }

    var body: some View {
        List {
            if viewModel.query.isEmpty {
                recentSearches
            } else {
                searchResults
            }
        }
        .listStyle(.plain)
        .scrollDismissesKeyboard(.interactively)
        .overlay { emptyState }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let track = viewModel.selection, !resultsContainSelection(track) {
                selectionSummary(track)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(uiColor: .systemBackground))
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { addButton }
        }
        .navigationTitle("曲を選ぶ")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $viewModel.searchText, prompt: "曲名・アーティスト名")
        .modifier(KeepToolbarDuringSearch())
        .onSubmit(of: .search) { viewModel.remember(viewModel.query) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, case .permissionDenied? = viewModel.searchError {
                retryCount += 1
            }
        }
        .confirmationDialog("検索履歴を消去しますか？", isPresented: $isConfirmingClearHistory, titleVisibility: .visible) {
            Button("履歴を消去", role: .destructive) { viewModel.clearHistory() }
            Button("キャンセル", role: .cancel) { }
        }
        .task(id: SearchRequest(query: viewModel.query, retryCount: retryCount)) {
            await viewModel.search()
        }
    }

    private var addButton: some View {
        Button {
            guard let selection = viewModel.selection else { return }
            selectedTrack = selection
            dismiss()
        } label: {
            Text("追加")
                .fontWeight(.semibold)
                .frame(minWidth: 44, minHeight: 44)
        }
        .disabled(viewModel.selection == nil)
        .accessibilityIdentifier("music.add")
        .accessibilityHint("選択した曲を追加して、保存前の確認に戻ります")
    }

    private func resultsContainSelection(_ track: Track) -> Bool {
        !viewModel.query.isEmpty && viewModel.resultsQuery == viewModel.query
            && viewModel.tracks.contains { $0.selectionID == track.selectionID }
    }

    private func selectionSummary(_ track: Track) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("選択した曲")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                MusicArtwork(track: track, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.name).font(.subheadline.weight(.semibold))
                    Text(track.artist).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("選択中の曲: \(track.name)、\(track.artist)")
        .accessibilityIdentifier("music.selection")
    }

    @ViewBuilder
    private var recentSearches: some View {
        if !viewModel.recentSearches.isEmpty {
            Section {
                ForEach(viewModel.recentSearches, id: \.self) { term in
                    Button {
                        viewModel.useRecentSearch(term)
                    } label: {
                        Label(term, systemImage: "clock.arrow.circlepath")
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("このキーワードで曲を検索します")
                }
            } header: {
                HStack {
                    Text("最近の検索")
                    Spacer()
                    Button("消去") { isConfirmingClearHistory = true }
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityLabel("検索履歴を消去")
                }
                .textCase(nil)
            }
        }
    }

    @ViewBuilder
    private var searchResults: some View {
        if viewModel.isSearching && !viewModel.tracks.isEmpty {
            HStack(spacing: 12) {
                ProgressView()
                Text("検索結果を更新中…").foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        }
        if let error = viewModel.searchError {
            searchFailure(error)
        }
        if !viewModel.tracks.isEmpty {
            Section {
                ForEach(viewModel.tracks) { track in
                    let isSelected = viewModel.selection?.selectionID == track.selectionID
                    HStack(spacing: 0) {
                        Button {
                            viewModel.select(track)
                        } label: {
                            HStack(spacing: 12) {
                                MusicArtwork(track: track)
                                trackInfo(track)
                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.tint)
                                        .accessibilityHidden(true)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isSearching || viewModel.resultsQuery != viewModel.query)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                        .accessibilityIdentifier(isSelected ? "music.selectedResult" : "music.result")
                        .accessibilityHint("写真に追加する曲として選択します")
                        if let url = track.serviceURL {
                            Link(destination: url) {
                                Image(systemName: "arrow.up.right")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(width: 44, height: 44)
                            }
                            .accessibilityLabel("Apple Musicで聴く")
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text(viewModel.resultsQuery == viewModel.query ? "曲" : "「\(viewModel.resultsQuery)」の検索結果")
                    .textCase(nil)
            }
        }
    }

    private func searchFailure(_ error: AppleMusicError) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            switch error {
            case .permissionDenied:
                Label("Apple Musicへのアクセスが必要です", systemImage: "lock")
                    .font(.headline)
                Text(error.localizedDescription).font(.subheadline).foregroundStyle(.secondary)
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    Link("設定を開く", destination: url)
                        .frame(minHeight: 44)
                }
            case .restricted:
                Label("Apple Musicへのアクセスが制限されています", systemImage: "lock")
                    .font(.headline)
            default:
                Label("検索できませんでした", systemImage: "exclamationmark.circle")
                    .font(.headline)
                Text(error.localizedDescription).font(.subheadline).foregroundStyle(.secondary)
                Button("再試行") { retryCount += 1 }
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44)
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var emptyState: some View {
        if viewModel.query.isEmpty && viewModel.recentSearches.isEmpty {
            ContentUnavailableView("写真に音楽を添える", systemImage: "music.note",
                                   description: Text("Apple Musicの曲名やアーティスト名で検索してください。"))
                .allowsHitTesting(false)
        } else if !viewModel.query.isEmpty && viewModel.tracks.isEmpty {
            if viewModel.isSearching {
                ProgressView("検索中…").allowsHitTesting(false)
            } else if viewModel.searchError == nil {
                ContentUnavailableView("曲が見つかりません", systemImage: "magnifyingglass",
                                       description: Text("別の曲名やアーティスト名で検索してください。"))
                    .allowsHitTesting(false)
            }
        }
    }

    private func trackInfo(_ track: Track) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(track.name).font(.body.weight(.semibold)).foregroundStyle(.primary)
            Text(track.artist).font(.subheadline).foregroundStyle(.secondary)
            if let album = track.albumName, !album.isEmpty {
                Text(album).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct KeepToolbarDuringSearch: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.searchPresentationToolbarBehavior(.avoidHidingContent)
        } else {
            content
        }
    }
}

struct MusicArtwork: View {
    let track: Track
    var size: CGFloat = 56

    var body: some View {
        AsyncImage(url: track.albumImages.first.flatMap(URL.init(string:))) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Image(systemName: "music.note")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(uiColor: .tertiarySystemFill))
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .accessibilityHidden(true)
    }
}
