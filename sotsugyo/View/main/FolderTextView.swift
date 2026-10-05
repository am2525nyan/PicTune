import SwiftUI
import FirebaseAuth
import CoreNFC

struct FolderTextView: View {
    @ObservedObject var viewModel: MainContentModel
    @Binding var folderDocument: String
    @State private var activeSheet: FolderSheet?

    private enum FolderSheet: Identifiable {
        case letter(id: String, name: String)
        case nfc(id: String, name: String)

        var id: String {
            switch self {
            case .letter(let id, _): return "letter-\(id)"
            case .nfc(let id, _): return "nfc-\(id)"
            }
        }
    }

    var body: some View {
        Group {
            if let folder = viewModel.folders.first(where: { $0.id == folderDocument }) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { actions(name: folder.title) }
                    VStack(spacing: 12) { actions(name: folder.title) }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            } else {
                ProgressView("フォルダを読み込み中…")
            }
        }
        .padding(.vertical, 12)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .letter(let id, let name):
                WriteLetterView(viewModel: viewModel, folderID: id, folderName: name)
            case .nfc(let id, let name):
                SaveFolderToNFCView(folderID: id, folderName: name)
            }
        }
    }

    @ViewBuilder
    private func actions(name: String) -> some View {
        Button {
            activeSheet = .letter(id: folderDocument, name: name)
        } label: {
            Label("手紙を見る・書く", systemImage: "envelope")
        }
        Button {
            activeSheet = .nfc(id: folderDocument, name: name)
        } label: {
            Label("NFCに保存", systemImage: "wave.3.right")
        }
    }
}

private struct SaveFolderToNFCView: View {
    let folderID: String
    let folderName: String
    @StateObject private var session = NFCSession()
    @Environment(\.dismiss) private var dismiss
    @State private var isWriting = false
    @State private var isSaved = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("保存するフォルダ") {
                    Label(folderName, systemImage: "folder")
                }
                Section {
                    Label(isSaved ? "NFCに保存しました" : "NFCカードを準備してください", systemImage: isSaved ? "checkmark.circle.fill" : "wave.3.right.circle")
                        .font(.headline)
                    Text("「保存を開始」をタップして、iPhoneの上部をNFCカードに近づけてください。")
                        .foregroundStyle(.secondary)
                    Text("カードにはフォルダへの参照を保存します。読み込むにはPicTuneとインターネット接続が必要です。カード内の既存データは上書きされます。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if !NFCNDEFReaderSession.readingAvailable {
                    Section {
                        Text("このデバイスではNFCへの保存を利用できません。")
                            .foregroundStyle(.secondary)
                    }
                }
                Section {
                    if isSaved {
                        Button("完了") { dismiss() }
                            .frame(maxWidth: .infinity, minHeight: 44)
                    } else {
                        Button { startWriting() } label: {
                            HStack {
                                if isWriting { ProgressView() }
                                Text(isWriting ? "保存中…" : "保存を開始")
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .disabled(isWriting || !NFCNDEFReaderSession.readingAvailable)
                    }
                }
                .listRowBackground(Color.clear)
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle("NFCに保存")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isSaved ? "閉じる" : "キャンセル") { dismiss() }
                        .disabled(isWriting)
                }
            }
            .alert("NFCに保存できませんでした", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .interactiveDismissDisabled(isWriting)
    }

    private func startWriting() {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "ログイン状態を確認して、もう一度お試しください。"
            return
        }
        isWriting = true
        session.startWriteSession(UserUid: uid, folder: folderID) { error in
            isWriting = false
            if let error = error {
                if (error as? NFCReaderError)?.code != .readerSessionInvalidationErrorUserCanceled {
                    errorMessage = error.localizedDescription
                }
            } else {
                isSaved = true
            }
        }
    }
}
