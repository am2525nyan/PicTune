import SwiftUI

struct ButtonView: View {
    @Binding var isPresentingCamera: Bool
    @Binding var showQRAlart: Bool
    @Binding var isPresentingQR: Bool

    var body: some View {
        Button {
            showQRAlart = true
        } label: {
            Label("撮影", systemImage: "camera")
        }
        .labelStyle(.iconOnly)
        .accessibilityLabel("撮影")
        .popoverTip(CameraTip())
        .alert("コード交換", isPresented: $showQRAlart) {
            Button("しない") {
                isPresentingCamera = true
            }
            Button("する") {
                isPresentingQR = true
            }
        } message: {
            Text("一緒のお友達のコードを読み込みますか？")
        }
    }
}
