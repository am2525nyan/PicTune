import XCTest

/// Exercises production views with local fixtures; screenshots are retained in the xcresult.
final class sotsugyoUITests: XCTestCase {
    @MainActor
    func testAnonymousLinkingAndSessionRestoration() {
        let app = XCUIApplication()
        app.launchArguments = ["-auth-emulator", "-auth-reset-session", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["設定"].waitForExistence(timeout: 20))
        app.tabBars.buttons["設定"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["auth.accountStatus"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["auth.accountStatus"].label.contains("匿名で利用中"))
        XCTAssertFalse(app.buttons["ログアウト"].exists)
        capture("auth-01-anonymous-settings", app: app)

        app.buttons["auth.connect.apple.com"].tap()
        XCTAssertTrue(app.buttons["auth.linkApple"].waitForExistence(timeout: 5))
        capture("auth-02-apple-link", app: app)
        app.buttons["キャンセル"].tap()
        app.buttons["auth.connect.google.com"].tap()
        XCTAssertTrue(app.buttons["auth.linkGoogle"].waitForExistence(timeout: 5))
        capture("auth-03-google-link", app: app)
        app.buttons["キャンセル"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["auth.accountStatus"].label.contains("匿名で利用中"))

        app.buttons["auth.connect.password"].tap()
        XCTAssertTrue(app.textFields["auth.email"].waitForExistence(timeout: 5))
        let email = "ui-\(UUID().uuidString.lowercased())@example.invalid"
        app.textFields["auth.email"].tap()
        app.textFields["auth.email"].typeText(email)
        XCTAssertFalse(app.buttons["auth.linkEmail"].isEnabled)
        app.secureTextFields["auth.password"].tap()
        app.secureTextFields["auth.password"].typeText("Linked123!")
        XCTAssertTrue(app.buttons["auth.linkEmail"].isEnabled)
        capture("auth-04-email-link", app: app)
        app.buttons["auth.linkEmail"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["auth.linked.password"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.descendants(matching: .any)["auth.accountStatus"].label.contains("匿名で利用中"))
        capture("auth-05-linked-settings", app: app)

        app.terminate()
        app.launchArguments.removeAll { $0 == "-auth-reset-session" }
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["設定"].waitForExistence(timeout: 15))
        app.tabBars.buttons["設定"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["auth.linked.password"].waitForExistence(timeout: 10))
        app.swipeUp()
        XCTAssertTrue(app.staticTexts[email].exists)
        app.buttons["ログアウト"].tap()
        app.alerts.buttons["ログアウト"].tap()
        XCTAssertTrue(app.buttons["既存のアカウントでログイン"].waitForExistence(timeout: 10))
        capture("auth-06-signed-out", app: app)
        app.buttons["既存のアカウントでログイン"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["auth.existingLogin"].waitForExistence(timeout: 10))
        capture("auth-07-existing-login", app: app)
        app.buttons["メールアドレスでログイン"].tap()
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 5))
        app.textFields.firstMatch.tap()
        app.textFields.firstMatch.typeText(email)
        app.buttons["次へ"].tap()
        XCTAssertTrue(app.secureTextFields.firstMatch.waitForExistence(timeout: 5))
        app.secureTextFields.firstMatch.tap()
        app.secureTextFields.firstMatch.typeText("Linked123!")
        app.buttons["ログイン"].tap()
        XCTAssertTrue(app.tabBars.buttons["設定"].waitForExistence(timeout: 15))
        app.tabBars.buttons["設定"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["auth.linked.password"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testAnonymousExistingLoginRequiresConfirmationAndKeepsSheetOpen() {
        let app = XCUIApplication()
        app.launchArguments = ["-auth-emulator", "-auth-reset-session", "-AppleLanguages", "(ja)"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["設定"].waitForExistence(timeout: 20))
        app.tabBars.buttons["設定"].tap()
        app.swipeUp()
        app.buttons["既存のアカウントでログイン"].tap()
        XCTAssertTrue(app.alerts["既存のアカウントに切り替えますか？"].waitForExistence(timeout: 5))
        app.alerts.buttons["キャンセル"].tap()
        app.swipeDown()
        XCTAssertTrue(app.descendants(matching: .any)["auth.accountStatus"].label.contains("匿名で利用中"))
        app.swipeUp()
        app.buttons["既存のアカウントでログイン"].tap()
        app.alerts.buttons["ログイン画面へ"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["auth.existingLogin"].waitForExistence(timeout: 10))
        capture("auth-08-existing-login-from-anonymous", app: app)
    }

    @MainActor
    func testAnonymousAccountCanBeDeletedAndStartedAgain() {
        let app = XCUIApplication()
        app.launchArguments = ["-auth-emulator", "-auth-reset-session", "-AppleLanguages", "(ja)"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["設定"].waitForExistence(timeout: 20))
        app.tabBars.buttons["設定"].tap()
        app.swipeUp()
        app.buttons["アカウントを削除"].tap()
        app.alerts.buttons["削除"].tap()
        XCTAssertTrue(app.buttons["auth.startAnonymous"].waitForExistence(timeout: 10))
        app.buttons["auth.startAnonymous"].tap()
        XCTAssertTrue(app.tabBars.buttons["設定"].waitForExistence(timeout: 15))
        app.tabBars.buttons["設定"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["auth.accountStatus"].label.contains("匿名で利用中"))
    }

    @MainActor
    func testInvitationOpeningAndLiveLetterUpdate() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-testing-invite", "-ui-testing-invite-update", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
        XCTAssertTrue(app.buttons["invite.open"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["invite.heading"].label, "夏の旅行")
        XCTAssertTrue(app.staticTexts["さきさんから"].exists)
        XCTAssertFalse(app.otherElements["invite.cover"].exists)
        attachScreenshot("招待の封筒")
        app.buttons["invite.open"].tap()
        // Keep accessibility snapshots off the animation path while recording.
        // Leave the app untouched through the reveal, then verify the result.
        Thread.sleep(forTimeInterval: 2.5)
        XCTAssertTrue(app.staticTexts["invite.received"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["invite.cover"].waitForExistence(timeout: 5))
        attachScreenshot("思い出の開封")
        app.buttons["invite.open"].tap()
        XCTAssertTrue(app.staticTexts["shared.letter"].waitForExistence(timeout: 10))
        let updated = NSPredicate(format: "label == %@", "旅行の写真を追加したよ。\nまたみんなで行こうね！")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: updated, object: app.staticTexts["shared.letter"])], timeout: 8), .completed)
        attachScreenshot("共有フォルダの同期")
    }

    @MainActor
    func testExpiredInvitationCannotBeOpened() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-testing-invite", "-ui-testing-invite-expired", "-AppleLanguages", "(ja)"]
        app.launch()
        XCTAssertTrue(app.staticTexts["invite.error"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["invite.open"].exists)
        attachScreenshot("招待の期限切れ")
    }

    @MainActor
    func testInvitationConnectionFailureDoesNotShowSuccess() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-testing-invite", "-ui-testing-invite-offline", "-AppleLanguages", "(ja)"]
        app.launch()
        XCTAssertTrue(app.buttons["invite.open"].waitForExistence(timeout: 10))
        app.buttons["invite.open"].tap()
        XCTAssertTrue(app.staticTexts["invite.error"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["invite.received"].exists)
        XCTAssertFalse(app.otherElements["invite.cover"].exists)
    }

    @MainActor
    func testInvitationStillOpensWithoutCoverPhoto() throws {
        for condition in ["-ui-testing-invite-empty", "-ui-testing-invite-image-failure"] {
            let app = XCUIApplication()
            app.launchArguments = ["-ui-testing", "-ui-testing-invite", condition, "-AppleLanguages", "(ja)"]
            app.launch()
            XCTAssertTrue(app.buttons["invite.open"].waitForExistence(timeout: 10))
            app.buttons["invite.open"].tap()
            XCTAssertTrue(app.staticTexts["invite.received"].waitForExistence(timeout: 5))
            XCTAssertFalse(app.otherElements["invite.cover"].exists)
            app.buttons["invite.open"].tap()
            XCTAssertTrue(app.staticTexts["shared.letter"].waitForExistence(timeout: 10))
            app.terminate()
        }
    }

    @MainActor
    func testCreateShareAndRevokeInvitation() throws {
        let app = launch()
        app.tabBars.buttons["フォルダ"].tap()
        app.buttons["卒業の思い出"].firstMatch.tap()
        XCTAssertTrue(app.buttons["folder.invite"].waitForExistence(timeout: 5))
        app.buttons["folder.invite"].tap()
        XCTAssertTrue(app.buttons["招待リンクを作る"].waitForExistence(timeout: 5))
        app.buttons["招待リンクを作る"].tap()
        XCTAssertTrue(app.buttons["invite.share"].waitForExistence(timeout: 5))
        attachScreenshot("招待リンクを贈る")
        app.buttons["このリンクを無効にする"].tap()
        app.buttons["リンクを無効にする"].tap()
        XCTAssertTrue(app.staticTexts["リンクを無効にしました。"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["invite.share"].exists)
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(editor: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        if editor { app.launchArguments.append("-ui-testing-editor") }
        app.launch()
        return app
    }

    @MainActor
    func testAppleMusicSearchSelectionEmptyAndDeniedStates() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--music-ui-test", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText("sample")
        XCTAssertTrue(app.staticTexts["Entropy"].firstMatch.waitForExistence(timeout: 5))
        app.staticTexts["Entropy"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["選択中"].waitForExistence(timeout: 3))
        attachScreenshot("Apple Music検索と選択")
        app.buttons["閉じる"].tap()
        XCTAssertTrue(app.buttons["追加"].isEnabled)
        search.tap()
        search.typeText("none")
        XCTAssertTrue(app.staticTexts["曲が見つかりません"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["選択中"].exists, "Selection should survive an empty result")
        search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4) + "error")
        XCTAssertTrue(app.staticTexts["設定アプリでPicTuneの「メディアとApple Music」へのアクセスを許可してください。"].waitForExistence(timeout: 5))
        attachScreenshot("Apple Music認可エラー")
        app.buttons["閉じる"].tap()
        XCTAssertTrue(app.buttons["追加"].isEnabled, "Selection should survive a failed search")
    }

    @MainActor
    func testPhotoDetailExplainsMissingPreview() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--music-ui-test", "--music-detail", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
        let preview = app.buttons["music.preview"]
        XCTAssertTrue(preview.waitForExistence(timeout: 10))
        preview.tap()
        XCTAssertTrue(app.staticTexts["この曲には試聴音源がありません。"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.links["music.serviceLink"].exists || app.buttons["music.serviceLink"].exists)
        attachScreenshot("写真詳細の試聴なし")
    }

    @MainActor
    func testLiveAppleMusicSearchPlaybackAndStop() throws {
        guard ProcessInfo.processInfo.environment["PICTUNE_RUN_LIVE_MUSIC"] == "1" else {
            throw XCTSkip("Opt-in only: needs an authorized device and live Apple Music access")
        }
        continueAfterFailure = true
        let app = XCUIApplication()
        app.launchArguments = ["--music-live-check", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
        defer {
            attachScreenshot("接続確認終了時")
            app.terminate()
        }
        app.buttons["検索を確認"].tap()
        let permissionAlert = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        if permissionAlert.waitForExistence(timeout: 3) {
            attachScreenshot("MusicKitの権限確認待ち")
            throw XCTSkip("Device permission needs user action; live verification has not completed")
        }
        let result = app.staticTexts["live.result"]
        let completed = NSPredicate(format: "label BEGINSWITH %@ OR label BEGINSWITH %@", "取得成功", "取得失敗")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: completed, object: result)], timeout: 45), .completed)
        attachScreenshot("Apple Music検索結果（実通信）")
        guard result.label.hasPrefix("取得成功") else {
            XCTFail("\(result.label) / \(app.staticTexts["live.connectionDetails"].label)")
            return
        }
        let preview = app.buttons["live.preview"]
        guard preview.waitForExistence(timeout: 10) else { XCTFail("No preview in search results"); return }
        preview.tap()
        app.swipeUp()
        let progressed = NSPredicate(format: "label MATCHES %@", "再生位置: ([3-9]|[1-9][0-9]+)秒")
        guard XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: progressed, object: app.staticTexts["live.elapsed"])], timeout: 30) == .completed else {
            let message = app.staticTexts["live.message"]
            XCTFail("Preview did not advance: \(app.staticTexts["live.state"].label) / \(app.staticTexts["live.elapsed"].label) / \(message.exists ? message.label : "no error message")")
            return
        }
        XCTAssertEqual(app.staticTexts["live.state"].label, "再生中")
        print("Live preview verification: \(app.staticTexts["live.elapsed"].label)")
        attachScreenshot("Apple Music試聴中（実通信）")
        preview.tap()
        XCTAssertEqual(app.staticTexts["live.state"].label, "停止中")
        attachScreenshot("Apple Music停止（実通信）")
    }

    @MainActor
    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testMutationFailuresAreVisible() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-testing-failures", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
        XCTAssertTrue(app.buttons["チェキ 1"].waitForExistence(timeout: 15))
        app.buttons["チェキ 1"].press(forDuration: 1)
        app.buttons["削除"].tap()
        XCTAssertTrue(app.alerts["写真の操作に失敗しました"].waitForExistence(timeout: 5))
        capture("20-photo-operation-error", app: app)
        app.alerts.buttons["閉じる"].tap()
        XCTAssertTrue(app.buttons["チェキ 1"].exists)

        app.tabBars.buttons["フォルダ"].tap()
        XCTAssertTrue(app.buttons["卒業の思い出"].waitForExistence(timeout: 5))
        app.buttons["フォルダを作成"].tap()
        app.alerts.textFields.firstMatch.typeText("test")
        app.alerts.buttons["作成"].tap()
        XCTAssertTrue(app.alerts["フォルダの操作に失敗しました"].waitForExistence(timeout: 5))
        capture("21-folder-operation-error", app: app)
        app.alerts.buttons["OK"].tap()

        app.tabBars.buttons["設定"].tap()
        app.buttons["ログアウト"].tap()
        app.alerts.buttons["ログアウト"].tap()
        XCTAssertTrue(app.alerts["操作を完了できませんでした"].waitForExistence(timeout: 5))
        capture("22-account-operation-error", app: app)
    }

    @MainActor
    func testLibraryAndPhotoDetails() {
        let app = launch()
        XCTAssertTrue(app.buttons["チェキ 1"].waitForExistence(timeout: 15))
        capture("01-photo-library", app: app)
        app.buttons["チェキ 1"].tap()
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["思い出の曲"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["思い出の曲"].isHittable)
        XCTAssertTrue(app.staticTexts["cheki-date"].label.contains("2024年3月1日"))
        XCTAssertTrue(app.staticTexts["cheki-date"].label.contains("12:30"))
        XCTAssertTrue(app.navigationBars.buttons["共有"].exists)
        app.buttons["music.preview"].tap()
        XCTAssertTrue(app.staticTexts["この曲には試聴音源がありません。"].waitForExistence(timeout: 5))
        capture("02-photo-with-music", app: app)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["チェキ 2"].tap()
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["cheki-date"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["cheki-date"].label.contains("2024年3月2日"))
        XCTAssertTrue(app.staticTexts["cheki-date"].label.contains("15:45"))
        XCTAssertFalse(app.staticTexts["思い出の曲"].exists)
        XCTAssertTrue(app.staticTexts["音楽は設定されていません"].exists)
        XCTAssertTrue(app.staticTexts["音楽は設定されていません"].isHittable)
        capture("03-photo-without-music", app: app)
    }

    @MainActor
    func testFoldersLetterAndNFC() {
        let app = launch()
        app.tabBars.buttons["フォルダ"].tap()
        XCTAssertTrue(app.buttons["卒業の思い出"].waitForExistence(timeout: 10))
        capture("04-folder-library", app: app)
        app.buttons["NFCを読み込む"].tap()
        XCTAssertTrue(app.alerts["NFC読み込み"].waitForExistence(timeout: 5))
        capture("05-nfc-read-unavailable", app: app)
        app.alerts.buttons["閉じる"].tap()
        app.buttons["卒業の思い出"].tap()
        XCTAssertTrue(app.staticTexts["2枚のチェキ"].waitForExistence(timeout: 5))
        capture("06-folder-detail", app: app)
        app.buttons["手紙を見る・書く"].tap()
        XCTAssertTrue(app.textViews["手紙の本文"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textViews["手紙の本文"].value as? String, "楽しい思い出をありがとう。\nまた一緒に写真を撮りましょう。")
        capture("07-letter", app: app)
        app.textViews["手紙の本文"].tap()
        app.textViews["手紙の本文"].typeText("\nUI確認")
        app.navigationBars.buttons["保存"].tap()
        XCTAssertTrue(app.buttons["手紙を見る・書く"].waitForExistence(timeout: 5))
        app.buttons["手紙を見る・書く"].tap()
        XCTAssertTrue(app.textViews["手紙の本文"].waitForExistence(timeout: 5))
        XCTAssertTrue((app.textViews["手紙の本文"].value as? String ?? "").contains("UI確認"))
        app.navigationBars.buttons["キャンセル"].tap()
        app.buttons["NFCに保存"].tap()
        XCTAssertTrue(app.staticTexts["このデバイスではNFCへの保存を利用できません。"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["保存を開始"].isEnabled)
        capture("08-nfc-write-unavailable", app: app)
    }

    @MainActor
    func testSettingsAndNameEditor() {
        let app = launch()
        app.tabBars.buttons["設定"].tap()
        XCTAssertTrue(app.staticTexts["demo@example.com"].waitForExistence(timeout: 5))
        capture("09-settings", app: app)
        app.buttons.containing(.staticText, identifier: "名前").firstMatch.tap()
        XCTAssertTrue(app.navigationBars["名前を編集"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["名前"].value as? String, "確認用ユーザー")
        capture("10-name-editor", app: app)
        app.buttons["キャンセル"].tap()
        app.buttons["ログアウト"].tap()
        XCTAssertTrue(app.alerts["ログアウトしますか？"].waitForExistence(timeout: 5))
        capture("11-logout-confirmation", app: app)
        app.alerts.buttons["キャンセル"].tap()
    }

    @MainActor
    func testPhotoEditorAndMusicSearch() {
        let app = launch(editor: true)
        XCTAssertTrue(app.navigationBars["写真を編集"].waitForExistence(timeout: 10))
        let editor = app.scrollViews["photo.editor.canvas"]
        XCTAssertTrue(editor.exists)
        XCTAssertGreaterThan(editor.frame.width, app.frame.width * 0.9)
        capture("12-photo-editor", app: app)
        app.buttons["スタンプ1"].tap()
        capture("13-photo-editor-stamp", app: app)
        app.buttons["ペン"].tap()
        XCTAssertTrue(app.staticTexts["指やApple Pencilで描けます。2本の指で拡大・縮小できます。"].waitForExistence(timeout: 5))
        let start = editor.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.4))
        let end = editor.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
        capture("14-photo-editor-pencil", app: app)
        editor.pinch(withScale: 2, velocity: 1)
        capture("14-photo-editor-zoomed", app: app)
        app.buttons["次へ"].tap()
        XCTAssertTrue(app.navigationBars["音楽を追加"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars.buttons["保存"].exists)
        capture("14-music-step", app: app)
        app.navigationBars.buttons["保存"].tap()
        XCTAssertTrue(app.alerts["保存できませんでした"].waitForExistence(timeout: 5))
        app.alerts.buttons["OK"].tap()
        app.buttons["音楽を追加"].tap()
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars.buttons["追加"].isEnabled)
        capture("15-music-search-empty", app: app)
    }

    @MainActor
    func testMusicSearchResultsAndFailures() {
        let app = XCUIApplication()
        let arguments = ["-ui-testing", "-ui-testing-search", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launchArguments = arguments
        app.launch()
        XCTAssertTrue(app.staticTexts["思い出の曲"].waitForExistence(timeout: 10))
        capture("16-music-search-results", app: app)
        app.buttons.containing(.staticText, identifier: "思い出の曲").firstMatch.tap()
        XCTAssertTrue(app.staticTexts["選択中"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars.buttons["追加"].isEnabled)
        capture("17-music-search-selected", app: app)
        app.terminate()

        app.launchArguments = arguments + ["-ui-testing-search-empty"]
        app.launch()
        XCTAssertTrue(app.staticTexts["曲が見つかりません"].waitForExistence(timeout: 10))
        capture("18-music-search-no-results", app: app)
        app.terminate()

        app.launchArguments = arguments + ["-ui-testing-search-error"]
        app.launch()
        XCTAssertTrue(app.staticTexts["検索できませんでした"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["再試行"].exists)
        capture("19-music-search-error", app: app)
    }

}
