import XCTest

@MainActor final class StaticPhotoUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-data", "--uitesting-photo", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["composeButton"].waitForExistence(timeout:15))
    }
    func testReferencePhotoCalculatesCentimetresAndSavesImage() {
        openPhoto("Q01")
        app.buttons["loadPhotoFixtureButton"].tap()
        let canvas = app.images["staticPhotoCanvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout:5))
        // 600×800 image: reference=200 px; target=400 px. Touch coordinates may round to device pixels.
        for point in [CGVector(dx:1.0/6,dy:0.125),CGVector(dx:1.0/6,dy:0.375),CGVector(dx:0.5,dy:0.125),CGVector(dx:0.5,dy:0.625)] {
            canvas.coordinate(withNormalizedOffset:point).tap()
        }
        let reference = app.textFields["photoReferenceLengthField"]
        reveal(reference); reference.tap(); reference.typeText("20")
        // Photo tool adds a keyboard dismissal action for decimal entry.
        if app.buttons["photoKeyboardDoneButton"].exists { app.buttons["photoKeyboardDoneButton"].tap() }
        for id in ["photoSamePlaneToggle","photoCorrectedToggle","photoConfirmedToggle"] {
            let toggle = app.switches[id]; reveal(toggle); toggle.tap()
        }
        let apply = app.buttons["applyPhotoPointsButton"]
        reveal(apply); XCTAssertTrue(apply.isEnabled)
        capture("static-photo-calibration")
        apply.tap()
        XCTAssertTrue(app.buttons["saveStaticMeasurementButton"].waitForExistence(timeout:5))
        let preview = app.buttons["calculateStaticMeasurementButton"]
        reveal(preview); preview.tap()
        let centimetres = app.staticTexts["staticResult-lengthCM"]
        XCTAssertTrue(centimetres.waitForExistence(timeout:5))
        let numeric = Double(centimetres.label.replacingOccurrences(of:" cm",with:"").replacingOccurrences(of:",",with:""))
        XCTAssertEqual(numeric ?? 0,40,accuracy:0.5)
        reveal(centimetres); capture("static-photo-result")
        let save = app.buttons["saveStaticMeasurementButton"]; reveal(save); save.tap()
        let record = app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@","staticRecord-")).firstMatch
        XCTAssertTrue(record.waitForExistence(timeout:5)); reveal(record); record.tap()
        let photo = app.images["staticRecordedPhoto"]; reveal(photo); XCTAssertTrue(photo.exists)
        capture("static-photo-history")
    }
    func testBlankPhotoCannotInventBodyModelPoints() {
        openPhoto("SM08")
        app.buttons["loadPhotoFixtureButton"].tap()
        let detect = app.buttons["detectBodyPointsButton"]; reveal(detect); detect.tap()
        let message = app.staticTexts["photoStatusMessage"]
        XCTAssertTrue(message.waitForExistence(timeout:15))
        let predicate = NSPredicate(format:"label CONTAINS %@", "手工")
        expectation(for:predicate,evaluatedWith:message)
        waitForExpectations(timeout:20)
        XCTAssertFalse(app.buttons["applyPhotoPointsButton"].isEnabled)
    }
    private func openPhoto(_ feature: String) {
        app.tabBars.buttons["测量"].tap()
        let library = app.buttons["staticMeasurementCatalogButton"]; reveal(library); library.tap()
        let search = app.textFields["staticCatalogSearchField"]; XCTAssertTrue(search.waitForExistence(timeout:5))
        search.tap(); search.typeText(feature)
        if app.buttons["keyboardDoneButton"].exists { app.buttons["keyboardDoneButton"].tap() }
        app.buttons["staticFeature-\(feature)"].tap()
        let record = app.buttons["recordStaticMeasurementButton"]; reveal(record); record.tap()
        app.buttons["staticPhotoMeasurementButton"].tap()
        XCTAssertTrue(app.buttons["loadPhotoFixtureButton"].waitForExistence(timeout:5))
    }
    private func reveal(_ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        for _ in 0..<16 {
            if element.isHittable { return }
            if element.frame.midY < app.frame.midY { app.swipeDown() } else { app.swipeUp() }
        }
        XCTAssertTrue(element.isHittable)
    }
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot:app.screenshot()); attachment.name=name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
