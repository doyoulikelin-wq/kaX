import XCTest

@MainActor final class StaticCatalogUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-data", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["composeButton"].waitForExistence(timeout: 15))
    }

    func testCatalogSearchAndReferenceLibraryBoundary() {
        openCatalog()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "24 项目录")).firstMatch.exists)
        capture("21-static-catalog")
        openFeature("H03")
        XCTAssertTrue(app.staticTexts["参考库尚未接入"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["recordStaticMeasurementButton"].exists)
        XCTAssertFalse(app.buttons["saveStaticMeasurementButton"].exists)
        capture("22-static-reference-library-boundary")
    }

    func testEllipseEstimateSavesRawInputsAndSurvivesRelaunch() {
        openCatalog()
        openFeature("H01")
        openForm()
        enter("widthCM", "30")
        enter("depthCM", "30")
        enter("level", "肚脐固定层面")
        // Exercise calculation while the final text input still owns the keyboard.
        let calculate = app.buttons["calculateStaticMeasurementButton"]
        reveal(calculate); calculate.tap()
        XCTAssertTrue(app.staticTexts["staticResult-ellipseEstimatedGirthCM"].waitForExistence(timeout: 5), app.debugDescription)
        reveal(app.staticTexts["staticResult-ellipseEstimatedGirthCM"])
        capture("23-static-ellipse-result")
        revealAndTap("saveStaticMeasurementButton")
        openLatestRecord()
        assertRawInput("widthCM", contains: "30")
        assertRawInput("depthCM", contains: "30")
        assertRawInput("level", contains: "肚脐固定层面")
        app.terminate()
        app.launchArguments.removeAll { $0 == "--reset-data" }
        app.launch()
        XCTAssertTrue(app.buttons["composeButton"].waitForExistence(timeout: 10))
        openCatalog()
        openFeature("H01")
        openLatestRecord()
        XCTAssertTrue(app.staticTexts["staticResult-ellipseEstimatedGirthCM"].waitForExistence(timeout: 5))
        assertRawInput("widthCM", contains: "30")
    }

    func testRepeatedLengthShowsSamplesAndCV() {
        openCatalog()
        openFeature("Q02")
        openForm()
        enter("repeats", "99, 100 101")
        choose("measurementType", option: "长度")
        enter("metricName", "三次独立重拍同层面长度")
        revealAndTap("calculateStaticMeasurementButton")
        XCTAssertTrue(app.staticTexts["staticResult-mean"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["staticResult-sampleSD"].exists)
        XCTAssertTrue(app.staticTexts["staticResult-cvPercent"].exists)
        reveal(app.staticTexts["staticResult-mean"])
        capture("24-static-repeat-length")
        revealAndTap("saveStaticMeasurementButton")
        openLatestRecord()
        assertRawInput("repeats", contains: "99")
        XCTAssertTrue(app.staticTexts["第 3 次：101"].exists)
    }

    func testRepeatedAnglesDoNotProduceCV() {
        openCatalog()
        openFeature("Q02")
        openForm()
        enter("repeats", "-1, 0, 1")
        choose("measurementType", option: "角度")
        enter("metricName", "三次独立重拍倾斜角")
        revealAndTap("calculateStaticMeasurementButton")
        XCTAssertTrue(app.staticTexts["staticResult-sampleSD"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["staticResult-cvPercent"].exists)
    }

    func testPersonalTargetRequiresExplicitParametersAndPersistsThem() {
        openCatalog()
        openFeature("H02")
        openForm()
        revealAndTap("addStaticTargetButton")
        enterTarget("observed", "1.1")
        enterTarget("lower", "1")
        enterTarget("upper", "1.2")
        enterTarget("scale", "0.1")
        enterTarget("weight", "1")
        revealAndTap("calculateStaticMeasurementButton")
        XCTAssertTrue(app.staticTexts["staticResult-targetMatch"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["staticResult-targetMatch"].label.contains("100"))
        reveal(app.staticTexts["staticResult-targetMatch"])
        capture("25-static-personal-target")
        revealAndTap("saveStaticMeasurementButton")
        openLatestRecord()
        let target = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "staticRecordedTarget-")).firstMatch
        reveal(target)
        XCTAssertTrue(target.label.contains("1.1"))
        XCTAssertTrue(target.label.contains("0.1"))
    }

    func testPhotoToolEntryDoesNotCreateARecordWithoutInput() {
        openCatalog()
        openFeature("SM08")
        openForm()
        revealAndTap("staticPhotoMeasurementButton")
        XCTAssertTrue(app.buttons["chooseStaticPhotoButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["applyPhotoPointsButton"].exists)
        app.buttons["cancelStaticPhotoButton"].tap()
        revealAndTap("saveStaticMeasurementButton")
        XCTAssertTrue(app.staticTexts["staticMeasurementError"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["cancelStaticMeasurementButton"].exists)
    }

    func testPhotoTwoPointPixelsSaveWithoutInventingCentimetres() {
        app.terminate()
        app.launchArguments.append("--uitesting-photo")
        app.launch()
        XCTAssertTrue(app.buttons["composeButton"].waitForExistence(timeout: 10))
        openCatalog()
        openFeature("Q01")
        openForm()
        revealAndTap("staticPhotoMeasurementButton")
        revealAndTap("loadPhotoFixtureButton")
        revealAndTap("photoPointPicker")
        let start = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "待测起点")).firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        let canvas = app.descendants(matching: .any).matching(identifier: "staticPhotoCanvas").firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        for _ in 0..<8 {
            let top = visibleContentFrame.minY
            guard canvas.frame.minY < top else { break }
            scrollContent(down: true, distance: top - canvas.frame.minY + 12)
        }
        XCTAssertGreaterThanOrEqual(canvas.frame.minY, visibleContentFrame.minY)
        XCTAssertLessThanOrEqual(canvas.frame.minY + canvas.frame.height * 0.5, visibleContentFrame.maxY)
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.25)).tap()
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5)).tap()
        let confirmed = app.switches["photoConfirmedToggle"]
        reveal(confirmed)
        confirmed.tap()
        revealAndTap("applyPhotoPointsButton")
        XCTAssertTrue(app.buttons["cancelStaticMeasurementButton"].waitForExistence(timeout: 5))
        revealAndTap("saveStaticMeasurementButton")
        openLatestRecord()
        XCTAssertTrue(app.staticTexts["staticResult-distancePixels"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["staticResult-lengthCM"].exists)
        assertRawInput("calibrationStatus", contains: "仅像素")
        XCTAssertTrue(app.images["staticRecordedPhoto"].exists || app.descendants(matching: .any).matching(identifier: "staticRecordedPhoto").firstMatch.exists)
        capture("26-static-photo-pixel-record")
    }

    func testDarkLargeTypeCatalogAndTargetForm() {
        app.terminate()
        app.launchArguments += ["--uitesting-dark", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"]
        app.launch()
        XCTAssertTrue(app.buttons["composeButton"].waitForExistence(timeout: 10))
        openCatalog()
        capture("27-static-dark-large-catalog")
        openFeature("H02")
        openForm()
        revealAndTap("addStaticTargetButton")
        let observed = app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH %@", "staticTarget-observed-")).firstMatch
        reveal(observed)
        XCTAssertTrue(observed.isHittable)
        capture("28-static-dark-large-target")
    }

    func testManualRatioUsesRankingOnlyAfterProtocolConfirmation() {
        openCatalog()
        openFeature("SM02")
        openForm()
        let toggle = app.switches["staticRankingProtocolToggle"]
        reveal(toggle)
        XCTAssertEqual(toggle.value as? String, "0")
        enter("armSpanCM", "198")
        enter("heightCM", "180")
        revealAndTap("saveStaticMeasurementButton")
        openLatestRecord()
        assertRawInput("armSpanCM", contains: "198")
        app.tabBars.buttons["排行"].tap()
        XCTAssertFalse(app.staticTexts["1.10"].exists)
        XCTAssertFalse(app.staticTexts["1.10 倍"].exists)
    }

    private func openCatalog() {
        app.tabBars.buttons["测量"].tap()
        revealAndTap("staticMeasurementCatalogButton")
        XCTAssertTrue(app.textFields["staticCatalogSearchField"].waitForExistence(timeout: 5))
    }

    private func openFeature(_ id: String) {
        let search = app.textFields["staticCatalogSearchField"]
        replace(search, with: id)
        dismissKeyboard()
        revealAndTap("staticFeature-\(id)")
        XCTAssertTrue(app.buttons["staticFeatureHistoryButton"].waitForExistence(timeout: 5))
    }

    private func openForm() {
        revealAndTap("recordStaticMeasurementButton")
        XCTAssertTrue(app.buttons["cancelStaticMeasurementButton"].waitForExistence(timeout: 5))
    }

    private func enter(_ key: String, _ value: String) {
        replace(editable("staticInput-\(key)"), with: value)
    }

    private func enterTarget(_ key: String, _ value: String) {
        let field = app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH %@", "staticTarget-\(key)-")).firstMatch
        replace(field, with: value)
    }

    private func choose(_ key: String, option: String) {
        dismissKeyboard()
        revealAndTap("staticInput-\(key)")
        let button = app.buttons[option].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
    }

    private func editable(_ id: String) -> XCUIElement {
        let field = app.textFields[id]
        return field.exists ? field : app.textViews[id]
    }

    private func replace(_ field: XCUIElement, with value: String) {
        dismissKeyboard()
        reveal(field)
        field.tap()
        if let current = field.value as? String, !current.isEmpty, current != field.placeholderValue {
            field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        field.typeText(value)
    }

    private func dismissKeyboard() {
        let button = app.buttons["keyboardDoneButton"]
        if button.exists && button.isHittable { button.tap() }
    }

    private func revealAndTap(_ id: String) {
        dismissKeyboard()
        let button = app.buttons[id]
        reveal(button)
        XCTAssertTrue(button.isEnabled)
        button.tap()
    }

    private func reveal(_ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), "Expected element: \(element)")
        for _ in 0..<18 {
            if element.isHittable { return }
            let visible = visibleContentFrame
            let frame = element.frame
            guard !frame.isEmpty else { break }
            if frame.minY < visible.minY {
                scrollContent(down: true, distance: visible.minY - frame.minY + 12)
            } else if frame.maxY > visible.maxY {
                scrollContent(down: false, distance: frame.maxY - visible.maxY + 12)
            } else {
                // A covered or disabled element is not fixed by blindly dragging the sheet.
                break
            }
        }
        XCTAssertTrue(element.isHittable, "Expected reachable element: \(element)")
    }

    private var visibleContentFrame: CGRect {
        let screen = app.frame
        let navigationBottom = app.navigationBars.allElementsBoundByIndex
            .filter { $0.exists && $0.frame.intersects(screen) }
            .map { $0.frame.maxY }.max() ?? screen.minY
        var bottom = screen.maxY - 12
        let tabBar = app.tabBars.firstMatch
        if tabBar.exists && tabBar.isHittable { bottom = min(bottom, tabBar.frame.minY) }
        let keyboard = app.keyboards.firstMatch
        if keyboard.exists { bottom = min(bottom, keyboard.frame.minY) }
        return CGRect(x: screen.minX, y: navigationBottom + 10, width: screen.width, height: max(1, bottom - navigationBottom - 10))
    }

    private func scrollContent(down: Bool, distance requestedDistance: CGFloat) {
        let viewport = visibleContentFrame
        let distance = min(requestedDistance, viewport.height * 0.4)
        let startY = down ? viewport.minY + viewport.height * 0.25 : viewport.maxY - viewport.height * 0.25
        let endY = startY + (down ? distance : -distance)
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: viewport.midX, dy: startY - app.frame.minY))
        let end = origin.withOffset(CGVector(dx: viewport.midX, dy: endY - app.frame.minY))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    private func openLatestRecord() {
        let record = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "staticRecord-")).firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        reveal(record)
        record.tap()
        XCTAssertTrue(app.staticTexts["原始输入"].waitForExistence(timeout: 5))
    }

    private func assertRawInput(_ key: String, contains text: String) {
        let value = app.descendants(matching: .any).matching(identifier: "staticRecordedInput-\(key)").firstMatch
        reveal(value)
        XCTAssertTrue(value.label.contains(text), "Expected raw input \(key) to contain \(text).")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
