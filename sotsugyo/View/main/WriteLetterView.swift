import SwiftUI

struct WriteLetterView: View {
    @ObservedObject var viewModel: MainContentModel
    let folderID: String
    let folderName: String
    @Environment(\.dismiss) private var dismiss
    @State private var userInput = ""
    @State private var originalText = ""
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var hasLoaded = false
    @State private var errorMessage: String?
    @State private var isDiscarding = false

    private var hasChanges: Bool { userInput != originalText }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label(folderName, systemImage: "folder")
                } header: {
                    Text("フォルダ")
                }
                Section {
                    if isLoading {
                        ProgressView("手紙を読み込み中…")
                    } else if hasLoaded {
                        TextEditor(text: $userInput)
                            .frame(minHeight: 240)
                            .accessibilityLabel("手紙の本文")
                            .disabled(isSaving)
                    } else {
                        Button("再読み込み") { Task { await loadLetter() } }
                    }
                } header: {
                    Text("手紙")
                } footer: {
                    Text("このフォルダに添えるメッセージを書けます。")
                }
            }
            .navigationTitle("手紙")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        if hasChanges { isDiscarding = true } else { dismiss() }
                    }
                    .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView().accessibilityLabel("保存中")
                    } else {
                        Button("保存") { saveLetter() }
                            .disabled(!hasLoaded || !hasChanges)
                    }
                }
            }
            .confirmationDialog("変更を破棄しますか？", isPresented: $isDiscarding, titleVisibility: .visible) {
                Button("変更を破棄", role: .destructive) { dismiss() }
                Button("編集を続ける", role: .cancel) {}
            }
            .alert("手紙を読み込み・保存できませんでした", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .interactiveDismissDisabled(hasChanges || isSaving)
        .task { await loadLetter() }
    }

    @MainActor
    private func loadLetter() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let letter = try await viewModel.loadLetter(folderID: folderID)
            userInput = letter
            originalText = letter
            hasLoaded = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveLetter() {
        isSaving = true
        Task { @MainActor in
            defer { isSaving = false }
            do {
                try await viewModel.saveLetter(userInput, folderID: folderID)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
