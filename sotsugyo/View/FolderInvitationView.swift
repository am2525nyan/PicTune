import SwiftUI

private enum GiftPalette {
    static let ink = Color(red: 0.23, green: 0.16, blue: 0.36)
    static let purple = Color(red: 0.49, green: 0.33, blue: 0.78)
}

struct FolderInvitationView: View {
    let link: FolderInviteLink
    @StateObject private var model: FolderInvitationModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var opened = false
    @State private var showFolder = false

    init(link: FolderInviteLink, repository: any FolderInvitationRepository = FirebaseFolderInvitationRepository()) {
        self.link = link
        _model = StateObject(wrappedValue: FolderInvitationModel(repository: repository))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GiftBackdrop()
                ScrollView {
                    VStack(spacing: 24) {
                        Label("PICTUNE  /  FOR YOU", systemImage: "sparkle")
                            .font(.system(size: 11, weight: .bold, design: .rounded)).tracking(3)
                            .padding(.top, 24)
                        VStack(spacing: 10) {
                            Text(opened ? "思い出が、\n届きました。" : "あなたへ、\n思い出の贈りもの。")
                                .font(.system(size: 32, weight: .heavy, design: .rounded))
                                .multilineTextAlignment(.center)
                                .accessibilityIdentifier("invite.heading")
                            Text(opened ? "これから増える思い出も、一緒に。" : "写真と音楽、伝えたい気持ちを込めて。")
                                .font(.subheadline).foregroundStyle(GiftPalette.ink.opacity(0.65))
                        }
                        GiftEnvelope(opened: opened, reduceMotion: reduceMotion)
                            .frame(height: 270)
                        if let invitation = model.invitation {
                            VStack(spacing: 8) {
                                Text(invitation.folder.title).font(.title3.bold()).multilineTextAlignment(.center)
                                Text("\(invitation.senderName)さんから").font(.subheadline)
                            }
                            .padding(.horizontal)
                        }
                        controls
                        Text("写真や手紙は、送り主が更新すると反映されます。\nあなたからの編集はできません。")
                            .font(.caption).foregroundStyle(GiftPalette.ink.opacity(0.65))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 28).padding(.bottom, 32)
                    .frame(maxWidth: 540).frame(maxWidth: .infinity)
                }
                if opened && !reduceMotion { GiftSparkles().allowsHitTesting(false).accessibilityHidden(true) }
            }
            .foregroundStyle(GiftPalette.ink)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly).disabled(model.isWorking && model.invitation != nil)
                }
            }
            .navigationDestination(isPresented: $showFolder) {
                if let received = model.received {
                    SharedFolderView(reference: received, repository: model.repository)
                }
            }
            .task { await model.load(link) }
            .onChange(of: model.received) { _, received in
                guard received != nil else { return }
                withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.85, dampingFraction: 0.7)) { opened = true }
            }
            .sensoryFeedback(.success, trigger: opened)
            .interactiveDismissDisabled(model.isWorking && model.invitation != nil)
        }
        .tint(GiftPalette.purple)
    }

    @ViewBuilder private var controls: some View {
        if let error = model.error {
            VStack(spacing: 12) {
                Text(error).font(.subheadline).multilineTextAlignment(.center).accessibilityIdentifier("invite.error")
                Button("もう一度試す") { Task { if model.invitation == nil { await model.load(link) } else { await model.receive() } } }
            }
        } else if model.invitation == nil {
            ProgressView("招待を確認しています…")
        } else {
            Button {
                if opened { showFolder = true } else { Task { await model.receive() } }
            } label: {
                HStack(spacing: 10) {
                    if model.isWorking { ProgressView().tint(.white) }
                    Text(model.isWorking ? "受け取り中…" : opened ? "思い出を見る" : "開いて受け取る")
                    if !model.isWorking { Image(systemName: opened ? "arrow.right" : "sparkles") }
                }
                .font(.headline).frame(maxWidth: .infinity, minHeight: 58)
                .foregroundStyle(.white)
                .background(LinearGradient(colors: [GiftPalette.purple, Color(red: 0.69, green: 0.43, blue: 0.72)], startPoint: .leading, endPoint: .trailing), in: Capsule())
                .shadow(color: GiftPalette.purple.opacity(0.23), radius: 15, y: 8)
            }
            .buttonStyle(.plain).disabled(model.isWorking)
            .accessibilityIdentifier("invite.open")
        }
    }
}

struct FolderInviteShareView: View {
    let folderID: String
    let folderName: String
    @StateObject private var model: FolderInvitationModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmRevoke = false
    init(folderID: String, folderName: String, repository: any FolderInvitationRepository = FirebaseFolderInvitationRepository()) {
        self.folderID = folderID; self.folderName = folderName
        _model = StateObject(wrappedValue: FolderInvitationModel(repository: repository))
    }
    var body: some View {
        NavigationStack {
            ZStack {
                GiftBackdrop()
                ScrollView {
                    VStack(spacing: 24) {
                        Label("PICTUNE  /  WITH LOVE", systemImage: "sparkle")
                            .font(.system(size: 11, weight: .bold)).tracking(3).padding(.top, 30)
                        Text("離れていても、\n思い出は一緒に。")
                            .font(.system(size: 32, weight: .heavy, design: .rounded)).multilineTextAlignment(.center)
                        GiftEnvelope(opened: false, reduceMotion: true).scaleEffect(0.88).frame(height: 240)
                        Text(folderName).font(.title3.bold())
                        Text("リンクを送って、写真・音楽・手紙を共有できます。\n受け取った後の変更も、相手に届きます。")
                            .font(.subheadline).multilineTextAlignment(.center)
                        if model.isWorking { ProgressView("リンクを準備しています…") }
                        else if let invitation = model.invitation, !model.isRevoked {
                            ShareLink(item: invitation.link.url, subject: Text("\(folderName)への招待"), message: Text("PicTuneで思い出を共有しましょう。")) {
                                Label("招待リンクを送る", systemImage: "square.and.arrow.up").foregroundStyle(.white)
                                    .font(.headline).frame(maxWidth: .infinity, minHeight: 54)
                            }
                            .buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
                            .accessibilityIdentifier("invite.share")
                            Text("\(invitation.expiresAt.formatted(date: .abbreviated, time: .omitted))まで参加できます。\nリンクを知っているログイン済みの方が閲覧できます。")
                                .font(.caption).multilineTextAlignment(.center)
                            Button("このリンクを無効にする", role: .destructive) { confirmRevoke = true }
                                .font(.footnote)
                        } else {
                            if model.isRevoked { Text("リンクを無効にしました。") }
                            Button(model.isRevoked ? "新しい招待リンクを作る" : "招待リンクを作る") { Task { await model.create(folderID: folderID) } }
                                .buttonStyle(.borderedProminent).controlSize(.large)
                        }
                        if let error = model.error { Text(error).font(.footnote).foregroundStyle(.red) }
                    }.padding(28).frame(maxWidth: 540).frame(maxWidth: .infinity)
                }
            }
            .foregroundStyle(GiftPalette.ink).tint(GiftPalette.purple)
            .navigationTitle("思い出を贈る").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() }.disabled(model.isWorking) } }
            .confirmationDialog("招待リンクを無効にしますか？", isPresented: $confirmRevoke, titleVisibility: .visible) {
                Button("リンクを無効にする", role: .destructive) { Task { await model.revoke() } }
            } message: { Text("このリンクからの新しい参加を停止します。参加済みの方との共有は続きます。") }
        }
        .interactiveDismissDisabled(model.isWorking)
    }
}

private struct GiftBackdrop: View {
    var body: some View {
        ZStack {
            Color(red: 0.98, green: 0.96, blue: 0.99)
            Ellipse().fill(Color.purple.opacity(0.13)).frame(width: 360, height: 460).blur(radius: 60).offset(x: -130, y: -130)
            Ellipse().fill(Color.pink.opacity(0.16)).frame(width: 300, height: 380).blur(radius: 70).offset(x: 160, y: 100)
            Circle().fill(Color.white.opacity(0.8)).frame(width: 260).blur(radius: 40)
        }.ignoresSafeArea()
    }
}

private struct GiftEnvelope: View {
    let opened: Bool
    let reduceMotion: Bool
    var body: some View {
        ZStack {
            Circle().fill(.white.opacity(0.8)).frame(width: 220, height: 220).blur(radius: 12).scaleEffect(opened ? 1.4 : 1)
            RoundedRectangle(cornerRadius: 24).fill(Color(red: 0.82, green: 0.72, blue: 0.9))
                .frame(width: 246, height: 162).rotationEffect(.degrees(-7)).offset(y: 36)
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(LinearGradient(colors: [.pink.opacity(0.35), .purple.opacity(0.5), .cyan.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: "music.note").font(.system(size: 44, weight: .light)).foregroundStyle(.white)
                }.frame(height: 108)
                Text("OUR LITTLE MEMORIES").font(.system(size: 8, weight: .bold)).tracking(2)
            }
            .padding(13).background(.white, in: RoundedRectangle(cornerRadius: 16))
            .frame(width: 176).rotationEffect(.degrees(opened ? -5 : 5))
            .offset(y: opened ? -48 : 12).scaleEffect(opened ? 1.12 : 0.9)
            .shadow(color: .purple.opacity(0.18), radius: 20, y: 12)
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(colors: [Color(red: 0.94, green: 0.86, blue: 0.96), Color(red: 0.84, green: 0.73, blue: 0.91)], startPoint: .top, endPoint: .bottom))
                .frame(width: 254, height: 142).overlay {
                    Image(systemName: opened ? "heart.fill" : "sparkles")
                        .font(.system(size: 25, weight: .light)).foregroundStyle(.white)
                        .padding(17).background(.white.opacity(0.22), in: Circle())
                }.rotationEffect(.degrees(-7)).offset(y: opened ? 72 : 68)
                .opacity(opened ? 0.75 : 1)
            ForEach(0..<7) { index in
                Image(systemName: index.isMultiple(of: 2) ? "sparkle" : "star.fill")
                    .font(.system(size: CGFloat(9 + index % 3 * 5)))
                    .foregroundStyle(index.isMultiple(of: 2) ? Color(red: 0.81, green: 0.64, blue: 0.32) : Color.purple.opacity(0.5))
                    .offset(x: CGFloat([-126, 116, -104, 122, 70, -70, 132][index]), y: CGFloat([-70, -80, 91, 83, -112, -119, 7][index]))
                    .scaleEffect(opened && !reduceMotion ? 1.4 : 1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(opened ? "開いた思い出の封筒" : "思い出を包んだ封筒")
    }
}

/// Time-based deterministic particles: no timers or repeat animations survive dismissal.
private struct GiftSparkles: View {
    @State private var start = Date()
    @State private var finished = false
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: finished)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(start)
            Canvas { context, size in
                guard elapsed < 2.5 else { return }
                for index in 0..<64 {
                    let angle = Double(index) * 2.39996
                    let distance = (1 - pow(1 - min(elapsed / 2.5, 1), 3)) * Double(100 + index % 9 * 26)
                    let point = CGPoint(x: size.width / 2 + cos(angle) * distance,
                                        y: size.height * 0.43 + sin(angle) * distance + elapsed * elapsed * 32)
                    let radius = CGFloat(index % 3 + 2)
                    var star = Path()
                    star.move(to: CGPoint(x: point.x, y: point.y - radius * 2))
                    star.addLine(to: CGPoint(x: point.x + radius, y: point.y))
                    star.addLine(to: CGPoint(x: point.x, y: point.y + radius * 2))
                    star.addLine(to: CGPoint(x: point.x - radius, y: point.y)); star.closeSubpath()
                    context.opacity = max(0, 1 - elapsed / 2.5)
                    context.fill(star, with: .color([Color.purple, .pink, Color(red: 0.9, green: 0.7, blue: 0.3), .white][index % 4]))
                }
            }
        }
        .task {
            do { try await Task.sleep(for: .milliseconds(2600)); finished = true }
            catch { return }
        }
    }
}
