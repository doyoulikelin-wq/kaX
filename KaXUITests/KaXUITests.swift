import XCTest

@MainActor final class KaXUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        await MainActor.run {
            continueAfterFailure = false
            app = XCUIApplication()
            app.launchArguments = ["--uitesting", "--reset-data", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
            app.launch()
            XCTAssertTrue(app.buttons["composeButton"].waitForExistence(timeout: 15))
        }
    }

    func testMainNavigationAndScreenshots() {
        capture("01-feed")
        tab("测量")
        XCTAssertTrue(app.buttons["bodyMeasurementButton"].waitForExistence(timeout: 5))
        capture("02-measurement")
        tab("排行")
        XCTAssertTrue(app.buttons["leaderboardInfoButton"].waitForExistence(timeout: 5))
        capture("03-ranking")
        tab("我的")
        XCTAssertTrue(app.buttons["editProfileButton"].waitForExistence(timeout: 5))
        capture("04-profile")
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(app.buttons["exportDataButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["resetDemoButton"].exists)
    }

    func testStrengthValidationSaveAndRelaunch() {
        tab("测量")
        app.buttons["strengthMeasurementButton"].tap()
        let weight = app.textFields["strengthWeightField"]
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["saveMeasurementButton"].isEnabled)
        replace(weight, with: "67.5")
        replace(app.textFields["strengthRepsField"], with: "31")
        XCTAssertFalse(app.buttons["saveMeasurementButton"].isEnabled)
        replace(app.textFields["strengthRepsField"], with: "6")
        dismissKeyboard()
        revealAndTap("saveMeasurementButton")
        waitForDismissal(of: weight)
        XCTAssertTrue(app.staticTexts["67.5"].firstMatch.waitForExistence(timeout: 5))
        relaunchWithoutReset()
        tab("测量")
        XCTAssertTrue(app.staticTexts["67.5"].firstMatch.waitForExistence(timeout: 5))
        capture("05-saved-strength")
    }

    func testBodyValidationAndAtomicProfileUpdate() {
        tab("测量")
        app.buttons["bodyMeasurementButton"].tap()
        let height = app.textFields["bodyHeightField"]
        XCTAssertTrue(height.waitForExistence(timeout: 5))
        replace(height, with: "0")
        XCTAssertFalse(app.buttons["saveMeasurementButton"].isEnabled)
        replace(height, with: "180")
        replace(app.textFields["bodyWeightField"], with: "72")
        replace(app.textFields["bodyArmSpanField"], with: "186")
        replace(app.textFields["bodyWaistField"], with: "81")
        dismissKeyboard()
        revealAndTap("saveMeasurementButton")
        waitForDismissal(of: height)
        tab("我的")
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["186"].firstMatch.waitForExistence(timeout: 5))
        capture("06-body-profile")
    }

    func testEditIdentityCardPersists() {
        tab("我的")
        app.buttons["editProfileButton"].tap()
        let name = app.textFields["profileNameField"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        replace(name, with: "卡片测试用户")
        app.buttons["saveProfileButton"].tap()
        XCTAssertTrue(app.staticTexts["卡片测试用户"].firstMatch.waitForExistence(timeout: 5))
        relaunchWithoutReset()
        tab("我的")
        XCTAssertTrue(app.staticTexts["卡片测试用户"].firstMatch.waitForExistence(timeout: 5))
    }

    func testPublishLikeAndComment() {
        app.buttons["composeButton"].tap()
        let caption = app.textViews["postCaptionField"].exists ? app.textViews["postCaptionField"] : app.textFields["postCaptionField"]
        XCTAssertTrue(caption.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["publishPostButton"].isEnabled)
        caption.tap()
        caption.typeText("今天记录了新的变化")
        app.buttons["publishPostButton"].tap()
        XCTAssertTrue(app.staticTexts["今天记录了新的变化"].firstMatch.waitForExistence(timeout: 5))
        let like = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "likeButton-")).firstMatch
        like.tap()
        XCTAssertTrue(like.label.contains("取消点赞"))
        like.tap()
        XCTAssertTrue(like.label.contains("点赞"))
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "commentButton-")).firstMatch.tap()
        let comment = app.textFields["commentField"]
        XCTAssertTrue(comment.waitForExistence(timeout: 5))
        comment.tap()
        comment.typeText("继续记录，一起进步")
        app.buttons["sendCommentButton"].tap()
        XCTAssertTrue(app.staticTexts["继续记录，一起进步"].waitForExistence(timeout: 5))
        capture("07-social-comment")
    }

    func testFollowingChangesFeedAndRankingScope() {
        let author = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "postAuthor-")).firstMatch
        author.tap()
        let follow = app.buttons["followButton-lin"]
        XCTAssertTrue(follow.waitForExistence(timeout: 5))
        XCTAssertTrue(follow.label.contains("取消关注"))
        follow.tap()
        XCTAssertEqual(follow.label, "关注林野")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.segmentedControls["feedFilterPicker"].buttons["关注"].tap()
        XCTAssertFalse(app.staticTexts["林野"].exists)
        tab("排行")
        app.segmentedControls["leaderboardFilterPicker"].buttons["关注"].tap()
        XCTAssertFalse(app.staticTexts["林野"].exists)
        app.segmentedControls["leaderboardFilterPicker"].buttons["全部"].tap()
        XCTAssertTrue(app.staticTexts["林野"].waitForExistence(timeout: 5))
    }

    func testShareCardProducesNativePreview() {
        tab("我的")
        revealAndTap("shareCardButton")
        let shareSheet = app.otherElements["ActivityListView"]
        XCTAssertTrue(shareSheet.waitForExistence(timeout: 8))
        let visible = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: shareSheet)
        XCTAssertEqual(XCTWaiter.wait(for: [visible], timeout: 5), .completed)
        XCTAssertFalse(app.alerts["暂时无法生成卡片"].exists)
        capture("12-native-card-share")
    }

    func testEMGCancelThenSaveDemo() {
        tab("测量")
        app.buttons["emgMeasurementButton"].tap()
        revealAndTap("startEMGButton")
        XCTAssertTrue(app.buttons["cancelEMGButton"].waitForExistence(timeout: 3))
        app.buttons["cancelEMGButton"].tap()
        XCTAssertTrue(app.buttons["startEMGButton"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["saveEMGButton"].exists)
        app.buttons["startEMGButton"].tap()
        XCTAssertTrue(app.buttons["saveEMGButton"].waitForExistence(timeout: 12))
        capture("08-emg-result")
        revealAndTap("saveEMGButton")
        XCTAssertTrue(app.buttons["emgMeasurementButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["演示肌电"].firstMatch.waitForExistence(timeout: 5))
    }

    func testDarkModeAndLargeType() {
        app.terminate()
        app.launchArguments += ["--uitesting-dark", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"]
        app.launch()
        XCTAssertTrue(app.buttons["composeButton"].waitForExistence(timeout: 10))
        capture("09-dark-large-feed")
        tab("测量")
        XCTAssertTrue(app.buttons["bodyMeasurementButton"].waitForExistence(timeout: 5))
        capture("10-dark-large-measurement")
        tab("我的")
        XCTAssertTrue(app.buttons["editProfileButton"].waitForExistence(timeout: 5))
        capture("11-dark-large-profile")
    }

    private func tab(_ name: String) { app.tabBars.buttons[name].tap() }

    private func replace(_ field: XCUIElement, with text: String) {
        // Dismiss the previous numeric keyboard before reaching fields below it on small phones.
        dismissKeyboard()
        field.tap()
        if let current = field.value as? String, !current.isEmpty, current != field.placeholderValue {
            field.press(forDuration: 1.1)
            let selectAll = app.menuItems["全选"].firstMatch
            if selectAll.waitForExistence(timeout: 2) { selectAll.tap() }
            let cut = app.menuItems["剪切"].firstMatch
            if cut.waitForExistence(timeout: 2) {
                cut.tap()
            } else {
                XCTFail("Text editing menu did not expose Cut: \(app.debugDescription)")
                return
            }
        }
        field.typeText(text)
        XCTAssertEqual(field.value as? String, text)
    }

    private func dismissKeyboard() {
        let done = app.buttons["keyboardDoneButton"]
        if done.exists { done.tap() }
    }

    private func waitForDismissal(of field: XCUIElement) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: field)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
    }

    private func revealAndTap(_ identifier: String) {
        let button = app.buttons[identifier]
        for _ in 0..<5 {
            if button.isHittable {
                XCTAssertTrue(button.isEnabled)
                button.tap(); return
            }
            app.swipeUp()
        }
        XCTAssertTrue(button.isHittable, "Button \(identifier) should be reachable")
        button.tap()
    }

    private func relaunchWithoutReset() {
        app.terminate()
        app.launchArguments.removeAll { $0 == "--reset-data" }
        app.launch()
        XCTAssertTrue(app.buttons["composeButton"].waitForExistence(timeout: 10))
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
