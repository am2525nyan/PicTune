//
//  sotsugyoUITests.swift
//  sotsugyoUITests
//
//  Created by saki on 2023/10/29.
//

import XCTest

final class sotsugyoUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
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
    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
