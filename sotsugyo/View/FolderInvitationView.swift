import SwiftUI

private enum GiftPalette {
    static let ink = Color(red: 0.36, green: 0.25, blue: 0.28)
    static let paper = Color(red: 1, green: 0.975, blue: 0.96)
    static let pink = Color(red: 0.98, green: 0.78, blue: 0.81)
    static let seam = Color(red: 0.85, green: 0.55, blue: 0.62)
    static let rose = Color(red: 0.73, green: 0.23, blue: 0.37)
    static let yellow = Color(red: 0.97, green: 0.77, blue: 0.40)
    static let blue = Color(red: 0.73, green: 0.86, blue: 0.90)
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
                        VStack(spacing: 12) {
                            Text(opened ? "思い出が、\n届きました。" : "思い出が\n届いています。")
                                .font(.system(size: 30, weight: .heavy, design: .rounded))
                                .multilineTextAlignment(.center)
                                .accessibilityIdentifier("invite.heading")
                            Text(opened ? "写真も、音楽も、手紙も。" : "写真と音楽、手紙をひとつに。")
                                .font(.subheadline.weight(.semibold)).foregroundStyle(GiftPalette.ink.opacity(0.65))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 16)
                        GiftEnvelope(opened: opened, reduceMotion: reduceMotion)
                            .frame(height: 250)
                        if let invitation = model.invitation {
                            VStack(spacing: 8) {
                                Text(invitation.folder.title).font(.system(.title3, design: .rounded, weight: .heavy)).multilineTextAlignment(.center)
                                Text("\(invitation.senderName)さんから").font(.subheadline.weight(.semibold))
                            }
                            .padding(.horizontal)
                        }
                        controls
                        Text("写真や手紙は、送り主が更新すると反映されます。\nあなたからの編集はできません。")
                            .font(.caption.weight(.medium)).foregroundStyle(GiftPalette.ink.opacity(0.65))
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
        .tint(GiftPalette.rose)
    }

    @ViewBuilder private var controls: some View {
        if let error = model.error {
            VStack(spacing: 12) {
                Text(error).font(.subheadline.weight(.medium)).multilineTextAlignment(.center).accessibilityIdentifier("invite.error")
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
                .font(.system(.headline, design: .rounded, weight: .heavy)).frame(maxWidth: .infinity, minHeight: 58)
                .foregroundStyle(.white)
                .background(GiftPalette.rose, in: Capsule())
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
                        Text("思い出を\nおすそわけ。")
                            .multilineTextAlignment(.center)
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.top, 12)
                        GiftEnvelope(opened: false, reduceMotion: true).scaleEffect(0.88).frame(height: 210)
                        Text(folderName).font(.system(.title3, design: .rounded, weight: .heavy))
                        Text("リンクを送って、写真・音楽・手紙を共有できます。\n受け取った後の変更も、相手に届きます。")
                            .font(.subheadline.weight(.medium)).multilineTextAlignment(.center)
                        if model.isWorking { ProgressView("リンクを準備しています…") }
                        else if let invitation = model.invitation, !model.isRevoked {
                            ShareLink(item: invitation.link.url, subject: Text("\(folderName)への招待"), message: Text("PicTuneで思い出を共有しましょう。")) {
                                Label("招待リンクを送る", systemImage: "square.and.arrow.up").foregroundStyle(.white)
                                    .font(.system(.headline, design: .rounded, weight: .heavy)).frame(maxWidth: .infinity, minHeight: 54)
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
                                .font(.headline.weight(.heavy)).buttonStyle(.borderedProminent).buttonBorderShape(.capsule).controlSize(.large)
                        }
                        if let error = model.error { Text(error).font(.footnote).foregroundStyle(.red) }
                    }.padding(28).frame(maxWidth: 540).frame(maxWidth: .infinity)
                }
            }
            .foregroundStyle(GiftPalette.ink).tint(GiftPalette.rose)
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
        GiftPalette.paper.overlay {
            Canvas { context, size in
                for row in 0...Int(size.height / 24) {
                    for column in 0...Int(size.width / 24) {
                        let x = CGFloat(column) * 24 + (row.isMultiple(of: 2) ? 0 : 12)
                        let dot = CGRect(x: x, y: CGFloat(row) * 24, width: 2, height: 2)
                        context.fill(Path(ellipseIn: dot), with: .color(GiftPalette.seam.opacity(0.14)))
                    }
                }
            }.accessibilityHidden(true)
        }.ignoresSafeArea()
    }
}

private struct GiftEnvelope: View {
    let opened: Bool
    let reduceMotion: Bool
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(GiftPalette.pink)
                .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(GiftPalette.seam, lineWidth: 1.2) }
                .frame(width: 242, height: 156)
                .rotationEffect(.degrees(-5)).offset(y: 28)
            EnvelopeFlap()
                .fill(GiftPalette.pink)
                .overlay { EnvelopeFlap().stroke(GiftPalette.seam, style: StrokeStyle(lineWidth: 1.2, lineJoin: .round)) }
                .frame(width: 242, height: 84)
                .rotation3DEffect(.degrees(opened ? 180 : 0), axis: (x: 1, y: 0, z: 0), anchor: .top)
                .rotationEffect(.degrees(-5)).offset(x: -4, y: -10)
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(GiftPalette.blue)
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 36)).foregroundStyle(.white.opacity(0.85)).offset(x: -34, y: -22)
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 26)).foregroundStyle(.white.opacity(0.85)).offset(x: 39, y: 24)
                    Image(systemName: "music.note")
                        .font(.system(size: 42, weight: .heavy)).foregroundStyle(GiftPalette.rose)
                        .rotationEffect(.degrees(-8))
                    Image(systemName: "heart.fill")
                        .font(.system(size: 13, weight: .bold)).foregroundStyle(.white).offset(x: 36, y: -28)
                }.frame(height: 96)
                HStack(spacing: 5) {
                    Image(systemName: "heart.fill").foregroundStyle(GiftPalette.rose)
                    Text("PicTune").fontWeight(.heavy)
                }.font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .padding(10)
            .background(.white, in: RoundedRectangle(cornerRadius: 10))
            .frame(width: 158)
            .rotationEffect(.degrees(opened ? 7 : 3))
            .offset(x: opened ? 10 : 0, y: opened ? -52 : 5)
            .scaleEffect(opened ? 1.08 : 0.94)
            .shadow(color: GiftPalette.seam.opacity(0.18), radius: 5, x: 0, y: 4)
            RoundedRectangle(cornerRadius: 16)
                .fill(GiftPalette.pink)
                .overlay {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: 0))
                        path.addQuadCurve(to: CGPoint(x: 121, y: 60), control: CGPoint(x: 76, y: 30))
                        path.addQuadCurve(to: CGPoint(x: 242, y: 0), control: CGPoint(x: 166, y: 30))
                    }.stroke(GiftPalette.seam, lineWidth: 1.2)
                }
                .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(GiftPalette.seam, lineWidth: 1.2) }
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(.white.opacity(0.8), style: StrokeStyle(lineWidth: 1.2, dash: [3, 4]))
                        .padding(7)
                }
                .overlay {
                    ZStack {
                        Image(systemName: "seal.fill").font(.system(size: 58)).foregroundStyle(GiftPalette.rose)
                        Image(systemName: "heart.fill").font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                    }
                    .rotationEffect(.degrees(10))
                    .scaleEffect(opened ? 1.08 : 1)
                    .offset(y: 4)
                }
                .frame(width: 242, height: 120)
                .rotationEffect(.degrees(-5)).offset(y: 57)
            ForEach(0..<3) { index in
                Image(systemName: index == 1 ? "sparkle" : "heart.fill")
                    .font(.system(size: CGFloat([16, 22, 11][index]), weight: .bold))
                    .foregroundStyle(index == 1 ? GiftPalette.yellow : GiftPalette.seam)
                    .rotationEffect(.degrees(index == 0 ? -18 : 15))
                    .offset(x: CGFloat([-128, 125, 112][index]), y: CGFloat([-60, -75, 106][index]))
                    .scaleEffect(opened && !reduceMotion ? 1.4 : 1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(opened ? "開いた思い出の封筒" : "思い出を包んだ封筒")
    }
}

private struct EnvelopeFlap: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.closeSubpath()
        }
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
                    context.fill(star, with: .color([GiftPalette.pink, GiftPalette.yellow, GiftPalette.rose, GiftPalette.blue][index % 4]))
                }
            }
        }
        .task {
            do { try await Task.sleep(for: .milliseconds(2600)); finished = true }
            catch { return }
        }
    }
}
