import XCTest

/// Exercises production views with local fixtures; screenshots are retained in the xcresult.
final class sotsugyoUITests: XCTestCase {
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
    func testLibraryAndPhotoDetails() {
        let app = launch()
        XCTAssertTrue(app.buttons["チェキ 1"].waitForExistence(timeout: 15))
        capture("01-photo-library", app: app)
        app.buttons["チェキ 1"].tap()
        XCTAssertTrue(app.staticTexts["思い出の曲"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["日付: 2024-03-01-12:30"].exists)
        capture("02-photo-with-music", app: app)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["チェキ 2"].tap()
        XCTAssertTrue(app.staticTexts["日付: 2024-03-02-15:45"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["思い出の曲"].exists)
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
        capture("12-photo-editor", app: app)
        app.buttons["スタンプ1"].tap()
        capture("13-photo-editor-stamp", app: app)
        app.buttons["ペン"].tap()
        XCTAssertTrue(app.staticTexts["写真に指やApple Pencilで描けます。"].waitForExistence(timeout: 5))
        capture("14-photo-editor-pencil", app: app)
        app.buttons["スタンプ"].tap()
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
