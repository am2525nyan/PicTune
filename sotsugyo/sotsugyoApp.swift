//
//  sotsugyoApp.swift
//  sotsugyo
//
//  Created by saki on 2023/10/29.
//

import SwiftUI
import FirebaseCore
import FirebaseAuthUI
import TipKit
#if DEBUG
import MusicKit
import AVFoundation
#endif
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        FirebaseApp.configure()
      
        return true
    }
    // MARK: URL Schemes
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any]) -> Bool {
        let sourceApplication = options[UIApplication.OpenURLOptionsKey.sourceApplication] as! String?
        if FUIAuth.defaultAuthUI()?.handleOpen(url, sourceApplication: sourceApplication) ?? false {
            return true
        }
        // other URL handling goes here.
        return false
    }
}

@main
struct sotsugyoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--music-live-check") {
                MusicLiveCheckScene()
            } else if ProcessInfo.processInfo.arguments.contains("--music-ui-test") {
                MusicUITestScene()
            } else {
                mainContent
            }
            #else
            mainContent
            #endif
        }
    }

    private var mainContent: some View {
        Group {
            #if DEBUG
            if UITestFixtures.isEnabled {
                UITestRootView()
            } else {
                MainContentView()
            }
            #else
            MainContentView()
            #endif
        }
            .environmentObject(SelectedImageManager.shared)
            .task {
                try? Tips.configure([
                    .displayFrequency(.immediate),
                    .datastoreLocation(.applicationDefault)
                ])
            }
    }

}

#if DEBUG
/// Opt-in device verification against the real service; does not write photo data.
private struct MusicLiveCheckScene: View {
    @StateObject private var player = MusicPreviewPlayer()
    @State private var track: Track?
    @State private var result = "未実行"
    @State private var elapsed = 0
    @State private var subscription = "未取得"
    @State private var connectionDetails = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("実サービスへの接続確認") {
                    Button("検索を確認") {
                        Task {
                            result = "検索中"
                            connectionDetails = ""
                            var catalogRequest: URLRequest?
                            let api = AppleMusicAPI(transport: { request in
                                catalogRequest = request
                                let (data, response) = try await URLSession.shared.data(for: request)
                                guard let response = response as? HTTPURLResponse else { throw AppleMusicError.invalidResponse }
                                connectionDetails = "HTTP \(response.statusCode)"
                                return (data, response)
                            })
                            do {
                                let tracks = try await api.searchTracks(query: "YOASOBI アイドル")
                                track = tracks.first { $0.previewURL != nil }
                                result = "取得成功: \(tracks.count)曲"
                                if let status = try? await MusicSubscription.current {
                                    subscription = "canPlayCatalogContent=\(status.canPlayCatalogContent)"
                                }
                            } catch {
                                let nsError = error as NSError
                                let reason = (error as? AppleMusicError)?.errorDescription
                                    ?? "\(nsError.domain) / \(nsError.code)"
                                if var request = catalogRequest {
                                    request.setValue(nil, forHTTPHeaderField: "Authorization")
                                    do {
                                        let response = try await MusicDataRequest(urlRequest: request).response()
                                        connectionDetails += " / MusicDataRequest: \(response.data.count) bytes"
                                    } catch let error as MusicDataRequest.Error {
                                        connectionDetails += " / MusicDataRequest: HTTP \(error.status), code \(error.code)"
                                    } catch {
                                        let error = error as NSError
                                        connectionDetails += " / MusicDataRequest: \(error.domain) / \(error.code)"
                                    }
                                }
                                result = "取得失敗: \(reason)"
                            }
                        }
                    }
                    Text(result).accessibilityIdentifier("live.result")
                    Text(connectionDetails).accessibilityIdentifier("live.connectionDetails")
                    Text("認可: \(String(describing: MusicAuthorization.currentStatus))")
                    Text(subscription).accessibilityIdentifier("live.subscription")
                }
                if let track {
                    Section("取得した楽曲") {
                        Text(track.name)
                        Text(track.artist)
                        Text("Storefront: \(track.storefront ?? "不明")")
                        AsyncImage(url: track.albumImages.first.flatMap(URL.init(string:))) { image in
                            image.resizable().scaledToFit()
                        } placeholder: { ProgressView() }
                        .frame(height: 100)
                        Button(player.state == .idle ? "試聴を確認" : "停止を確認") {
                            player.toggle(track)
                        }.accessibilityIdentifier("live.preview")
                        Text(player.state == .playing ? "再生中" : player.state == .loading ? "準備中" : "停止中")
                            .accessibilityIdentifier("live.state")
                        Text("再生位置: \(elapsed)秒").accessibilityIdentifier("live.elapsed")
                        if let message = player.message { Text(message).accessibilityIdentifier("live.message") }
                        if let url = track.serviceURL { Link("Apple Musicで聴く", destination: url) }
                    }
                }
            }
            .navigationTitle("Apple Music接続確認")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                while !Task.isCancelled {
                    let seconds = player.audioPlayer?.currentTime().seconds ?? 0
                    elapsed = seconds.isFinite ? Int(seconds) : 0
                    try? await Task.sleep(for: .milliseconds(250))
                }
            }
            .onDisappear { player.stop() }
        }
    }
}

/// Offline UI fixtures: no Apple Music or Firestore requests are made by this scene.
private struct MusicUITestScene: View {
    @State private var selectedTrack: Track?

    static let track = Track(id: "1613600188", name: "Entropy", artist: "Beach Bunny", albumImages: [],
                             previewURL: nil, albumName: "Emotional Creature",
                             musicURL: "https://music.apple.com/us/album/entropy/1613600183?i=1613600188", storefront: "us")

    var body: some View {
        NavigationStack {
            if ProcessInfo.processInfo.arguments.contains("--music-detail") {
                ImageDetailView(photo: LibraryPhoto(record: PhotoRecord(
                    id: "fixture", fileName: "fixture.jpg", date: Date(timeIntervalSince1970: 1_791_241_200),
                    music: FirebaseMusic(photoID: "fixture", track: Self.track), livePhotoFileName: ""),
                    image: Self.sampleImage), resolvePreview: { $0 })
            } else {
                SearchView(selectedTrack: $selectedTrack, viewModel: SearchViewModel(search: { query in
                    if query == "error" { throw AppleMusicError.permissionDenied }
                    if query == "none" { return [] }
                    return [Self.track]
                }))
            }
        }
    }

    static var sampleImage: UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 333, height: 260)).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 333, height: 260))
            UIImage(systemName: "mountain.2.fill")?.withTintColor(.white, renderingMode: .alwaysOriginal)
                .draw(in: CGRect(x: 76, y: 65, width: 180, height: 140))
        }
    }
}

#endif
