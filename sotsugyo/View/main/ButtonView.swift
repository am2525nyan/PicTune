import SwiftUI

struct ButtonView: View {
    @Binding var isPresentingCamera: Bool
    @Binding var showQRAlart: Bool
    @Binding var isPresentingQR: Bool

    var body: some View {
        Button {
            showQRAlart = true
        } label: {
            cameraLabel
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.16), radius: 12, x: 0, y: 6)
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

    @ViewBuilder
    private var cameraLabel: some View {
        if #available(iOS 26.0, *) {
            cameraIcon
                .glassEffect(.regular.interactive(), in: Circle())
        } else {
            cameraIcon
                .background(.regularMaterial, in: Circle())
        }
    }

    private var cameraIcon: some View {
        Label("撮影", systemImage: "camera.fill")
            .labelStyle(.iconOnly)
            .font(.system(size: 24, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(width: 64, height: 64)
            .contentShape(Circle())
    }
}
