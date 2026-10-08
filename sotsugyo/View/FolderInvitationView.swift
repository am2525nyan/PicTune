import SwiftUI

enum GiftPalette {
    static let ink = Color.primary
    static let purple = Color(red: 0.49, green: 0.33, blue: 0.78)
    static let purpleText = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.76, green: 0.63, blue: 0.95, alpha: 1)
            : UIColor(red: 0.49, green: 0.33, blue: 0.78, alpha: 1)
    })
}

struct FolderInvitationView: View {
    let link: FolderInviteLink
    @StateObject private var model: FolderInvitationModel
    @StateObject private var preview: SharedFolderModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var opened = false
    @State private var showFolder = false

    init(link: FolderInviteLink, repository: any FolderInvitationRepository = FirebaseFolderInvitationRepository()) {
        self.link = link
        _model = StateObject(wrappedValue: FolderInvitationModel(repository: repository))
        #if DEBUG
        if UITestFixtures.isEnabled {
            _preview = StateObject(wrappedValue: SharedFolderModel(repository: repository, photoLimit: 1, imageLoader: { _, _ in
                if ProcessInfo.processInfo.arguments.contains("-ui-testing-invite-image-failure") { throw URLError(.notConnectedToInternet) }
                return UITestFixtures.image().pngData()!
            }))
        } else {
            _preview = StateObject(wrappedValue: SharedFolderModel(repository: repository, photoLimit: 1))
        }
        #else
        _preview = StateObject(wrappedValue: SharedFolderModel(repository: repository, photoLimit: 1))
        #endif
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GiftBackdrop()
                ScrollView {
                    VStack(spacing: 24) {
                        if let invitation = model.invitation {
                            VStack(spacing: 18) {
                                Text("\(invitation.senderName)さんから")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(GiftPalette.purpleText)
                                    .padding(.horizontal, 16).padding(.vertical, 8)
                                    .background(GiftPalette.purple.opacity(0.08), in: Capsule())
                                Text(invitation.folder.title)
                                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                                    .multilineTextAlignment(.center)
                                    .accessibilityIdentifier("invite.heading")
                            }
                            .padding(.top, 24)
                            GiftEnvelope(opened: opened, title: invitation.folder.title, coverImage: preview.photos.first?.image)
                                .scaleEffect(0.85).frame(height: 310)
                                .accessibilityIdentifier(preview.photos.isEmpty ? "invite.envelope" : "invite.cover")
                            Label("受け取りました", systemImage: "checkmark.circle.fill")
                                .font(.headline).foregroundStyle(GiftPalette.purpleText)
                                .opacity(opened ? 1 : 0)
                                .accessibilityHidden(!opened)
                                .accessibilityIdentifier("invite.received")
                        }
                        controls
                        if model.invitation != nil {
                            VStack(spacing: 8) {
                                Label("相手の更新もここに反映されます", systemImage: "arrow.triangle.2.circlepath")
                                    .font(.footnote.weight(.medium))
                                Text("写真や手紙を見ることができます。編集はできません。")
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 2)
                        }
                    }
                    .padding(24)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 28))
                    .padding(.horizontal, 20).padding(.vertical, 24)
                    .frame(maxWidth: 540).frame(maxWidth: .infinity)
                }
                if opened && !reduceMotion { GiftSparkles().allowsHitTesting(false).accessibilityHidden(true) }
            }
            .foregroundStyle(GiftPalette.ink)
            .navigationTitle("届いた思い出").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly).disabled(model.isWorking && model.invitation != nil)
                }
            }
            .navigationDestination(isPresented: $showFolder) {
                if let received = model.received {
                    SharedFolderView(reference: received, senderName: model.invitation?.senderName, repository: model.repository)
                }
            }
            .task { await model.load(link) }
            .task(id: "\(model.received?.id ?? "")-\(scenePhase == .active)-\(showFolder)") {
                guard let received = model.received, scenePhase == .active, !showFolder else { return }
                await preview.observe(received)
            }
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
            VStack(spacing: 20) {
                if model.invitation == nil {
                    Image(systemName: "envelope.badge")
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(GiftPalette.purple)
                        .padding(.top, 64)
                }
                Text(error).font(.subheadline).multilineTextAlignment(.center).accessibilityIdentifier("invite.error")
                Button("もう一度試す") { Task { if model.invitation == nil { await model.load(link) } else { await model.receive() } } }
                    .buttonStyle(.bordered).controlSize(.large)
            }
        } else if model.invitation == nil {
            ProgressView("招待を確認しています…")
                .padding(.top, 80)
        } else {
            Button {
                if opened { showFolder = true } else { Task { await model.receive() } }
            } label: {
                HStack(spacing: 10) {
                    if model.isWorking { ProgressView().tint(.white) }
                    Text(model.isWorking ? "受け取り中…" : opened ? "思い出を見る" : "受け取って開く")
                }
                .font(.headline).frame(maxWidth: .infinity, minHeight: 58)
                .foregroundStyle(.white)
                .background(GiftPalette.purple, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain).disabled(model.isWorking)
            .accessibilityIdentifier("invite.open")
        }
    }
}

struct FolderInviteShareView: View {
    let folderID: String
    let folderName: String
    let coverImage: UIImage?
    @StateObject private var model: FolderInvitationModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmRevoke = false
    init(folderID: String, folderName: String, coverImage: UIImage? = nil, repository: any FolderInvitationRepository = FirebaseFolderInvitationRepository()) {
        self.folderID = folderID; self.folderName = folderName; self.coverImage = coverImage
        _model = StateObject(wrappedValue: FolderInvitationModel(repository: repository))
    }
    var body: some View {
        NavigationStack {
            ZStack {
                GiftBackdrop()
                ScrollView {
                    VStack(spacing: 24) {
                        Text(folderName)
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .multilineTextAlignment(.center).padding(.top, 20)
                        GiftEnvelope(opened: true, title: folderName, coverImage: coverImage).scaleEffect(0.85).frame(height: 310)
                        Text("写真に音楽や手紙を添えて、\nリンクで送れます。")
                            .font(.subheadline).multilineTextAlignment(.center)
                        if model.isWorking { ProgressView("リンクを準備しています…") }
                        else if let invitation = model.invitation, !model.isRevoked {
                            ShareLink(item: invitation.link.url, subject: Text("\(folderName)への招待"), message: Text("PicTuneの「\(folderName)」への招待です。")) {
                                Label("招待リンクを送る", systemImage: "square.and.arrow.up").foregroundStyle(.white)
                                    .font(.headline).frame(maxWidth: .infinity, minHeight: 54)
                            }
                            .buttonStyle(.borderedProminent).buttonBorderShape(.roundedRectangle(radius: 16))
                            .accessibilityIdentifier("invite.share")
                            Text("\(invitation.expiresAt.formatted(date: .abbreviated, time: .omitted))まで参加できます。\nリンクを知っている方は、ログインすると参加できます。")
                                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                            Button("このリンクを無効にする", role: .destructive) { confirmRevoke = true }
                                .font(.footnote)
                        } else {
                            if model.isRevoked { Text("リンクを無効にしました。") }
                            Button(model.isRevoked ? "新しい招待リンクを作る" : "招待リンクを作る") { Task { await model.create(folderID: folderID) } }
                                .buttonStyle(.borderedProminent).controlSize(.large)
                        }
                        Text("送ったあとに写真や手紙を更新すると、相手にも反映されます。")
                            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        if let error = model.error { Text(error).font(.footnote).foregroundStyle(.red) }
                    }
                    .padding(24)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 28))
                    .padding(.horizontal, 20).padding(.vertical, 24)
                    .frame(maxWidth: 540).frame(maxWidth: .infinity)
                }
            }
            .foregroundStyle(GiftPalette.ink).tint(GiftPalette.purple)
            .navigationTitle("思い出を送る").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() }.disabled(model.isWorking) } }
            .confirmationDialog("招待リンクを無効にしますか？", isPresented: $confirmRevoke, titleVisibility: .visible) {
                Button("リンクを無効にする", role: .destructive) { Task { await model.revoke() } }
            } message: { Text("このリンクからは参加できなくなります。すでに受け取った相手は、引き続きフォルダを見られます。") }
        }
        .interactiveDismissDisabled(model.isWorking)
    }
}

struct GiftBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(red: 0.13, green: 0.14, blue: 0.22), Color(red: 0.20, green: 0.14, blue: 0.25)]
                : [Color(red: 0.82, green: 0.86, blue: 0.98), Color(red: 0.89, green: 0.80, blue: 0.97)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        ).ignoresSafeArea()
    }
}

private struct GiftEnvelope: View {
    let opened: Bool
    let title: String
    var coverImage: UIImage? = nil
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24).fill(Color(red: 0.82, green: 0.72, blue: 0.9))
                .frame(width: 246, height: 162).rotationEffect(.degrees(-7)).offset(y: 36)
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "heart").font(.system(size: 16, weight: .semibold)).foregroundStyle(.pink.opacity(0.6))
                ForEach(0..<3) { _ in Capsule().fill(GiftPalette.purple.opacity(0.15)).frame(height: 2) }
                Spacer(minLength: 0)
            }
            .padding(18).frame(width: 138, height: 154)
            .background(Color(red: 1, green: 0.98, blue: 0.97), in: RoundedRectangle(cornerRadius: 4))
            .rotationEffect(.degrees(12)).offset(x: 52, y: opened ? -38 : 28)
            .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
            Group {
                if let coverImage {
                    // Saved images already include the cheki border and handwritten decoration.
                    Image(uiImage: coverImage).resizable().scaledToFit()
                } else {
                    VStack(spacing: 12) {
                        ZStack {
                            Rectangle().fill(LinearGradient(colors: [Color(red: 0.78, green: 0.86, blue: 0.98), Color(red: 0.87, green: 0.76, blue: 0.95)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            Image(systemName: "music.note").font(.system(size: 40, weight: .medium)).foregroundStyle(.white)
                        }
                        Text(title).font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(GiftPalette.purple).lineLimit(1)
                            .frame(height: 26)
                    }
                    .padding(.horizontal, 12).padding(.top, 18).padding(.bottom, 16)
                }
            }
            .frame(width: 170, height: 270)
            .background(.white)
            .overlay { Rectangle().strokeBorder(.black.opacity(0.08), lineWidth: 0.7) }
            .rotationEffect(.degrees(opened ? -7 : 5))
            .offset(x: opened ? -12 : 0, y: opened ? -40 : 32).scaleEffect(opened ? 1.04 : 0.72)
            .shadow(color: .black.opacity(0.16), radius: 10, y: 6)
            .zIndex(opened ? 1 : 0)
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(colors: [Color(red: 0.94, green: 0.86, blue: 0.96), Color(red: 0.84, green: 0.73, blue: 0.91)], startPoint: .top, endPoint: .bottom))
                .frame(width: 254, height: 142).overlay {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 23, weight: .medium)).foregroundStyle(.white)
                        .padding(16).background(Color(red: 0.92, green: 0.68, blue: 0.80), in: Circle())
                        .offset(y: opened ? 28 : 0)
                }.rotationEffect(.degrees(-7)).offset(y: opened ? 102 : 68)
                .opacity(opened ? 0.75 : 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(coverImage != nil ? "\(title)のチェキを添えた封筒" : opened ? "開いた招待の封筒" : "招待の封筒")
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
