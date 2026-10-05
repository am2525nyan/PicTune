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
            if ProcessInfo.processInfo.arguments.contains("--music-ui-test") {
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
        MainContentView()
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
/// Offline UI fixtures: no Apple Music or Firestore requests are made by this scene.
private struct MusicUITestScene: View {
    @State private var selectedTrack: Track?
    @StateObject private var model = MusicUITestModel()

    static let track = Track(id: "1613600188", name: "Entropy", artist: "Beach Bunny", albumImages: [],
                             previewURL: nil, albumName: "Emotional Creature",
                             musicURL: "https://music.apple.com/us/album/entropy/1613600183?i=1613600188", storefront: "us")

    var body: some View {
        NavigationStack {
            if ProcessInfo.processInfo.arguments.contains("--music-detail") {
                ImageDetailView(image: .constant(Self.sampleImage), documentId: .constant("fixture"),
                                tapdocumentId: .constant("fixture"), index: .constant(0), viewModel: model,
                                friendUid: .constant(""), selectedIndex: 0, resolvePreview: { $0 })
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

private final class MusicUITestModel: MainContentModel {
    override func getDate() async throws { }

    @MainActor
    override func getMusic(documentId: String, folder: String, friendUid: String) async throws {
        dates = ["2026-10-06"]
        Music = [FirebaseMusic.from(documentID: "fixture", data: MusicUITestScene.track.firestoreData)!]
    }
}
#endif
