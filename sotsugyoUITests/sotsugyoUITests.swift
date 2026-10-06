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
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["思い出の曲"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["思い出の曲"].isHittable)
        XCTAssertTrue(app.staticTexts["cheki-date"].label.contains("2024年3月1日"))
        XCTAssertTrue(app.staticTexts["cheki-date"].label.contains("12:30"))
        XCTAssertTrue(app.navigationBars.buttons["共有"].exists)
        XCTAssertTrue(app.staticTexts["この曲は試聴できません"].exists)
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
