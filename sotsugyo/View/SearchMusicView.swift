import SwiftUI

struct SearchView: View {
    @Binding var selectedTrack: Track?
    @Environment(\.dismiss) private var dismiss
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
            if let track = viewModel.selection {
                selectedTrackSummary(track)
            }
        }
        .navigationTitle("音楽を追加")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $viewModel.searchText, prompt: "Apple Musicで曲名・アーティスト名を検索")
        .onSubmit(of: .search) { viewModel.remember(viewModel.query) }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("追加") {
                    guard let selection = viewModel.selection else { return }
                    selectedTrack = selection
                    dismiss()
                }
                .fontWeight(.semibold)
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.selection == nil)
                .accessibilityHint("選択した曲を写真に追加して、写真編集に戻ります")
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
            VStack(alignment: .leading, spacing: 8) {
                Label("検索できませんでした", systemImage: "wifi.exclamationmark")
                    .font(.headline)
                Text(error).font(.subheadline).foregroundStyle(.secondary)
                Button("再試行") { retryCount += 1 }
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44)
            }
            .padding(.vertical, 8)
        }
        if !viewModel.tracks.isEmpty {
            Section {
                ForEach(viewModel.tracks) { track in
                    VStack(alignment: .leading, spacing: 4) {
                        Button {
                            viewModel.select(track)
                        } label: {
                            HStack(spacing: 12) {
                                MusicArtwork(track: track)
                                trackInfo(track)
                                Spacer(minLength: 8)
                                Image(systemName: viewModel.selection?.selectionID == track.selectionID ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(viewModel.selection?.selectionID == track.selectionID ? Color.accentColor : Color.secondary)
                                    .font(.title3)
                                    .accessibilityHidden(true)
                            }
                            .frame(minHeight: 56)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isSearching || viewModel.resultsQuery != viewModel.query)
                        .accessibilityAddTraits(viewModel.selection?.selectionID == track.selectionID ? .isSelected : [])
                        .accessibilityHint("写真に追加する曲として選択します")
                        if let url = track.serviceURL {
                            Link("Apple Musicで聴く", destination: url)
                                .font(.caption)
                                .padding(.leading, 64)
                                .frame(minHeight: 32)
                        }
                    }
                }
            } header: {
                Text(viewModel.resultsQuery == viewModel.query ? "曲" : "「\(viewModel.resultsQuery)」の検索結果")
                    .textCase(nil)
            }
        }
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

    private func selectedTrackSummary(_ track: Track) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("選択中").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                MusicArtwork(track: track)
                trackInfo(track)
                Spacer(minLength: 0)
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .accessibilityElement(children: .combine)
    }

    private func trackInfo(_ track: Track) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(track.name).font(.body).foregroundStyle(.primary).lineLimit(2)
            Text(track.artist).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            if let album = track.albumName, !album.isEmpty {
                Text(album).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MusicArtwork: View {
    let track: Track

    var body: some View {
        AsyncImage(url: track.albumImages.first.flatMap(URL.init(string:))) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Image(systemName: "music.note")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(uiColor: .tertiarySystemFill))
        }
        .frame(width: 52, height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .accessibilityHidden(true)
    }
}
