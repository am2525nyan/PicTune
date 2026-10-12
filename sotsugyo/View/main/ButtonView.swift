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
        .confirmationDialog("撮影方法を選択", isPresented: $showQRAlart, titleVisibility: .visible) {
            Button("一人で撮る") {
                isPresentingCamera = true
            }
            Button("友達と撮る") {
                isPresentingQR = true
            }
        } message: {
            Text("友達と撮る場合は、QRコードを読み取るか見せてください。")
        }
    }
}
