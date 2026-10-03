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
        XCTAssertFalse(app.buttons["rankEntry-lin"].exists)
        app.segmentedControls["leaderboardFilterPicker"].buttons["全部"].tap()
        XCTAssertTrue(app.buttons["rankEntry-lin"].waitForExistence(timeout: 5))
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
        tab("排行")
        XCTAssertTrue(app.buttons["rankingMetricPicker"].waitForExistence(timeout: 5))
        capture("16-dark-large-static-ranking")
        tab("我的")
        XCTAssertTrue(app.buttons["editProfileButton"].waitForExistence(timeout: 5))
        capture("11-dark-large-profile")
        for _ in 0..<5 {
            if app.staticTexts["身体档案"].firstMatch.isHittable { break }
            app.swipeUp()
        }
        capture("19-dark-large-body-profile")
    }

    func testStaticLegRatioValidationEvidenceAndPersistence() {
        tab("排行")
        selectRankingMetric("legBodyRatio")
        app.buttons["leaderboardInfoButton"].tap()
        XCTAssertTrue(app.staticTexts["rankingFormula"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "SM07")).firstMatch.exists)
        capture("17-static-evidence")
        app.buttons["closeRankingEvidenceButton"].tap()
        revealAndTap("recordRankingMeasurementButton")
        let height = app.textFields["rankingInput-heightCM"]
        XCTAssertTrue(height.waitForExistence(timeout: 5))
        replace(height, with: "180")
        replace(app.textFields["rankingInput-sittingHeightCM"], with: "190")
        XCTAssertFalse(app.buttons["saveRankingMeasurementButton"].isEnabled)
        replace(app.textFields["rankingInput-sittingHeightCM"], with: "90")
        dismissKeyboard()
        XCTAssertTrue(app.staticTexts["rankingCalculatedValue"].label.contains("0.50"))
        app.buttons["saveRankingMeasurementButton"].tap()
        waitForDismissal(of: height)
        XCTAssertTrue(app.otherElements["currentUserRank"].waitForExistence(timeout: 5))
        capture("13-static-leg-ratio")
        relaunchWithoutReset()
        tab("排行")
        selectRankingMetric("legBodyRatio")
        XCTAssertTrue(app.otherElements["currentUserRank"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["0.50 倍"].firstMatch.exists || app.staticTexts["0.50"].firstMatch.exists)
    }

    func testStaticWidthsAndGirthsStaySeparate() {
        tab("排行")
        app.segmentedControls["rankingCategoryPicker"].buttons["当前形体"].tap()
        selectRankingMetric("shoulderWaistWidthRatio")
        revealAndTap("recordRankingMeasurementButton")
        let shoulder = app.textFields["rankingInput-shoulderWidthCM"]
        XCTAssertTrue(shoulder.waitForExistence(timeout: 5))
        replace(shoulder, with: "48")
        replace(app.textFields["rankingInput-waistWidthCM"], with: "32")
        dismissKeyboard()
        app.buttons["saveRankingMeasurementButton"].tap()
        waitForDismissal(of: shoulder)
        XCTAssertTrue(app.staticTexts["1.50"].firstMatch.waitForExistence(timeout: 5))
        selectRankingMetric("waistHipGirthRatio")
        revealAndTap("recordRankingMeasurementButton")
        let waist = app.textFields["rankingInput-waistGirthCM"]
        XCTAssertTrue(waist.waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["rankingInput-waistWidthCM"].exists)
        replace(waist, with: "80")
        replace(app.textFields["rankingInput-hipGirthCM"], with: "100")
        dismissKeyboard()
        app.buttons["saveRankingMeasurementButton"].tap()
        waitForDismissal(of: waist)
        XCTAssertTrue(app.staticTexts["0.80"].firstMatch.waitForExistence(timeout: 5))
        capture("14-static-girth-ratio")
        selectRankingMetric("shoulderWaistWidthRatio")
        XCTAssertTrue(app.staticTexts["1.50"].firstMatch.exists)
    }

    func testStaticArmSpanUpdatesIdentityCard() {
        tab("排行")
        revealAndTap("recordRankingMeasurementButton")
        let armSpan = app.textFields["rankingInput-armSpanCM"]
        XCTAssertTrue(armSpan.waitForExistence(timeout: 5))
        replace(armSpan, with: "198")
        replace(app.textFields["rankingInput-heightCM"], with: "180")
        dismissKeyboard()
        app.buttons["saveRankingMeasurementButton"].tap()
        waitForDismissal(of: armSpan)
        tab("我的")
        XCTAssertTrue(app.staticTexts["1.1"].firstMatch.waitForExistence(timeout: 5) || app.staticTexts["1.10"].firstMatch.exists)
        capture("15-static-identity-card")
        let recent = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "recentRanking-")).firstMatch
        for _ in 0..<5 {
            if recent.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(recent.isHittable)
        recent.tap()
        capture("18-static-record-detail")
        let detailSpan = app.descendants(matching: .any).matching(identifier: "rankingInput-armSpanCM").firstMatch
        let detailHeight = app.descendants(matching: .any).matching(identifier: "rankingInput-heightCM").firstMatch
        XCTAssertTrue(detailSpan.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(detailSpan.label.contains("198"))
        XCTAssertTrue(detailHeight.label.contains("180"))
        app.navigationBars.buttons["完成"].tap()
        for _ in 0..<5 {
            if app.buttons["editProfileButton"].isHittable { break }
            app.swipeDown()
        }
        app.buttons["editProfileButton"].tap()
        app.buttons["featuredMetricPicker"].tap()
        app.buttons["记录习惯"].tap()
        app.buttons["saveProfileButton"].tap()
        // SwiftUI propagates this card's identifier to its text children.
        let monthCount = app.staticTexts.matching(NSPredicate(format: "identifier == %@ AND label == %@", "identityCard", "1")).firstMatch
        XCTAssertTrue(monthCount.waitForExistence(timeout: 5))
        capture("20-static-month-count")
    }

    private func selectRankingMetric(_ identifier: String) {
        app.buttons["rankingMetricPicker"].tap()
        let option = app.buttons["selectMetric-\(identifier)"]
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        option.tap()
    }

    private func tab(_ name: String) { app.tabBars.buttons[name].tap() }

    private func replace(_ field: XCUIElement, with text: String) {
        // Dismiss the previous numeric keyboard before reaching fields below it on small phones.
        dismissKeyboard()
        for _ in 0..<4 {
            if field.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(field.isHittable)
        field.tap()
        if let current = field.value as? String, !current.isEmpty, current != field.placeholderValue {
            field.press(forDuration: 1.1)
            let selectAll = app.menuItems["全选"].firstMatch
            if selectAll.waitForExistence(timeout: 2) { selectAll.tap() }
            let cut = app.menuItems["剪切"].firstMatch
            if cut.waitForExistence(timeout: 2) {
                cut.tap()
            } else {
                // Numeric fields do not always expose the edit menu on this simulator.
                // Tap past the rendered number to place the insertion point at its end.
                field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
                field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
            }
            let cleared = field.value as? String ?? ""
            XCTAssertTrue(cleared.isEmpty || cleared == field.placeholderValue)
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
