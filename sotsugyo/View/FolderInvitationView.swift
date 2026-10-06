import SwiftUI

private enum GiftPalette {
    static let ink = Color(red: 0.16, green: 0.16, blue: 0.18)
    static let paper = Color(red: 0.97, green: 0.96, blue: 0.93)
    static let lilac = Color(red: 0.77, green: 0.73, blue: 0.90)
    static let yellow = Color(red: 0.98, green: 0.79, blue: 0.30)
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
                        VStack(alignment: .leading, spacing: 12) {
                            Text(opened ? "思い出が、\n届きました。" : "思い出が\n届いています。")
                                .font(.system(size: 34, weight: .black, design: .rounded))
                                .multilineTextAlignment(.leading)
                                .accessibilityIdentifier("invite.heading")
                            Text(opened ? "写真も、音楽も、手紙も。" : "写真と音楽、手紙をひとつに。")
                                .font(.subheadline.weight(.semibold)).foregroundStyle(GiftPalette.ink.opacity(0.65))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
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
        .tint(GiftPalette.ink)
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
                .background(GiftPalette.ink, in: RoundedRectangle(cornerRadius: 18))
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
                        Text("思い出を\nリンクで送る。")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .frame(maxWidth: .infinity, alignment: .leading)
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
                            .buttonStyle(.borderedProminent).buttonBorderShape(.roundedRectangle(radius: 18))
                            .accessibilityIdentifier("invite.share")
                            Text("\(invitation.expiresAt.formatted(date: .abbreviated, time: .omitted))まで参加できます。\nリンクを知っているログイン済みの方が閲覧できます。")
                                .font(.caption).multilineTextAlignment(.center)
                            Button("このリンクを無効にする", role: .destructive) { confirmRevoke = true }
                                .font(.footnote)
                        } else {
                            if model.isRevoked { Text("リンクを無効にしました。") }
                            Button(model.isRevoked ? "新しい招待リンクを作る" : "招待リンクを作る") { Task { await model.create(folderID: folderID) } }
                                .font(.headline.weight(.heavy)).buttonStyle(.borderedProminent).controlSize(.large)
                        }
                        if let error = model.error { Text(error).font(.footnote).foregroundStyle(.red) }
                    }.padding(28).frame(maxWidth: 540).frame(maxWidth: .infinity)
                }
            }
            .foregroundStyle(GiftPalette.ink).tint(GiftPalette.ink)
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
        GiftPalette.paper.ignoresSafeArea()
    }
}

private struct GiftEnvelope: View {
    let opened: Bool
    let reduceMotion: Bool
    var body: some View {
        ZStack {
            // Flat paper layers keep the opening motion legible without a glowing backdrop.
            RoundedRectangle(cornerRadius: 8)
                .fill(GiftPalette.lilac)
                .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(GiftPalette.ink, lineWidth: 2) }
                .frame(width: 246, height: 156)
                .rotationEffect(.degrees(-6)).offset(y: 28)
            EnvelopeFlap()
                .fill(GiftPalette.lilac)
                .overlay { EnvelopeFlap().stroke(GiftPalette.ink, style: StrokeStyle(lineWidth: 2, lineJoin: .round)) }
                .frame(width: 246, height: 84)
                .rotation3DEffect(.degrees(opened ? 180 : 0), axis: (x: 1, y: 0, z: 0), anchor: .top)
                .rotationEffect(.degrees(-6)).offset(x: -5, y: -10)
            VStack(spacing: 10) {
                ZStack {
                    Rectangle().fill(GiftPalette.yellow)
                    Image(systemName: "music.note")
                        .font(.system(size: 46, weight: .black)).foregroundStyle(GiftPalette.ink)
                }.frame(height: 96)
                HStack(spacing: 5) {
                    Image(systemName: "heart.fill")
                    Text("PicTune").fontWeight(.black)
                }.font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .padding(10)
            .background(.white, in: RoundedRectangle(cornerRadius: 3))
            .overlay { RoundedRectangle(cornerRadius: 3).strokeBorder(GiftPalette.ink, lineWidth: 2) }
            .frame(width: 158)
            .rotationEffect(.degrees(opened ? 7 : 3))
            .offset(x: opened ? 10 : 0, y: opened ? -52 : 5)
            .scaleEffect(opened ? 1.08 : 0.94)
            .shadow(color: GiftPalette.ink.opacity(0.12), radius: 0, x: 4, y: 4)
            RoundedRectangle(cornerRadius: 8)
                .fill(GiftPalette.lilac)
                .overlay {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: 0))
                        path.addLine(to: CGPoint(x: 123, y: 64))
                        path.addLine(to: CGPoint(x: 246, y: 0))
                    }.stroke(GiftPalette.ink, lineWidth: 2)
                }
                .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(GiftPalette.ink, lineWidth: 2) }
                .overlay {
                    Image(systemName: opened ? "checkmark" : "heart.fill")
                        .font(.system(size: 18, weight: .black))
                        .frame(width: 44, height: 44)
                        .background(GiftPalette.yellow, in: Circle())
                        .overlay { Circle().strokeBorder(GiftPalette.ink, lineWidth: 2) }
                        .offset(y: 6)
                }
                .frame(width: 246, height: 120)
                .rotationEffect(.degrees(-6)).offset(y: 57)
            ForEach(0..<3) { index in
                Image(systemName: "sparkle")
                    .font(.system(size: CGFloat([24, 17, 12][index]), weight: .bold))
                    .foregroundStyle(index == 0 ? GiftPalette.ink : GiftPalette.yellow)
                    .offset(x: CGFloat([-132, 132, 113][index]), y: CGFloat([-60, -75, 106][index]))
                    .scaleEffect(opened && !reduceMotion ? 1.5 : 1)
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
                    context.fill(star, with: .color([GiftPalette.lilac, GiftPalette.yellow, GiftPalette.ink, .white][index % 4]))
                }
            }
        }
        .task {
            do { try await Task.sleep(for: .milliseconds(2600)); finished = true }
            catch { return }
        }
    }
}
