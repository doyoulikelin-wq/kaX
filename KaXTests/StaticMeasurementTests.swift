import XCTest
@testable import KaX

final class StaticMeasurementTests: XCTestCase {
    private let confirmed = ["calibrationStatus": "已校正且共面"]
    private func number(_ result: StaticMeasurementResult, _ key: String) throws -> Double {
        try XCTUnwrap(result.values.first { $0.id == key }?.value)
    }
    private func calculate(_ feature: StaticFeatureID, _ values: [String: Double], text: [String: String] = [:]) throws -> StaticMeasurementResult {
        try StaticMeasurementCalculator.calculate(feature: feature, input: StaticMeasurementInput(values: values, text: text))
    }

    func testBundledCatalogContainsExact24IDsAndCompleteOriginalSources() throws {
        XCTAssertNil(StaticFeatureCatalog.loadingError)
        XCTAssertEqual(StaticFeatureCatalog.all.count, 24)
        XCTAssertEqual(Set(StaticFeatureCatalog.all.map(\.id)), Set(StaticFeatureID.allCases))
        for item in StaticFeatureCatalog.all {
            XCTAssertFalse(item.formula.isEmpty)
            XCTAssertFalse(item.data.isEmpty)
            XCTAssertFalse(item.measurementGuide.isEmpty)
            XCTAssertEqual(item.sourceIDs, item.sourceReferences.map(\.id))
            XCTAssertFalse(item.sourceReferences.isEmpty)
        }
        XCTAssertEqual(StaticFeatureCatalog.metadata(for: .h03)?.availability, .requiresReferenceLibrary)
        XCTAssertTrue(StaticFeatureCatalog.metadata(for: .h01)!.formula.contains("∫"))
    }

    func testPixelScaleOnlyProducesCentimetresWithDeclaredGeometryConditions() throws {
        let values = ["referenceLengthCM": 20.0, "referencePixels": 100, "groundY": 100, "vertexY": 1000]
        let centimetres = try calculate(.sm01, values, text: confirmed)
        XCTAssertEqual(try number(centimetres, "heightCM"), 180)
        XCTAssertEqual(try number(centimetres, "scaleCMPerPixel"), 0.2)
        let pixels = try calculate(.sm01, values, text: ["calibrationStatus": "仅像素"])
        XCTAssertEqual(try number(pixels, "heightPixels"), 900)
        XCTAssertFalse(pixels.values.contains { $0.unit == "cm" || $0.unit == "cm/px" })
        let q = try calculate(.q01, ["referenceLengthCM": 20, "referencePixels": 100, "distancePixels": 50], text: confirmed)
        XCTAssertEqual(try number(q, "lengthCM"), 10)
        let onlyPixels = try calculate(.q01, ["distancePixels": 50], text: ["calibrationStatus": "仅像素"])
        XCTAssertEqual(onlyPixels.values.map(\.unit), ["px"])
        XCTAssertThrowsError(try calculate(.q01, ["distancePixels": 50], text: confirmed))
        XCTAssertThrowsError(try calculate(.q01, ["distancePixels": 50, "referencePixels": 100], text: ["calibrationStatus": "仅像素"]))
        XCTAssertThrowsError(try calculate(.q01, ["referenceLengthCM": 20, "referencePixels": 0, "distancePixels": 50], text: confirmed))
        XCTAssertThrowsError(try calculate(.sm01, ["groundY": 100, "vertexY": 100], text: ["calibrationStatus": "仅像素"]))
    }

    func testManualDimensionsRetainOriginalRatioDifferenceAndBMIFormulas() throws {
        let span = try calculate(.sm02, ["armSpanCM": 184, "heightCM": 178])
        XCTAssertEqual(try number(span, "armSpanRatio"), 184.0 / 178, accuracy: 0.000001)
        XCTAssertEqual(try number(span, "armSpanDifferenceCM"), 6)
        let shoulder = try calculate(.sm03, ["shoulderWidthCM": 46, "heightCM": 178])
        XCTAssertEqual(try number(shoulder, "relativeShoulderWidth"), 46.0 / 178, accuracy: 0.000001)
        let shape = try calculate(.sm04, ["shoulderWidthCM": 46, "waistWidthCM": 28, "hipWidthCM": 35], text: ["waistLevel": "固定肚脐层面"])
        XCTAssertEqual(try number(shape, "shoulderWaistWidthRatio"), 46.0 / 28, accuracy: 0.000001)
        XCTAssertEqual(try number(shape, "waistHipWidthRatio"), 0.8)
        let depth = try calculate(.sm05, ["widthCM": 30, "depthCM": 20], text: ["level": "同次固定腰线"])
        XCTAssertEqual(try number(depth, "widthDepthRatio"), 1.5)
        let legs = try calculate(.sm07, ["heightCM": 178, "sittingHeightCM": 92])
        XCTAssertEqual(try number(legs, "relativeLegLengthCM"), 86)
        XCTAssertEqual(try number(legs, "legBodyRatio") + number(legs, "sittingHeightRatio"), 1, accuracy: 0.000001)
        let bmi = try calculate(.sm13, ["weightKG": 72, "heightCM": 180])
        XCTAssertEqual(try number(bmi, "bmi"), 72 / (1.8 * 1.8), accuracy: 0.000001)
        XCTAssertThrowsError(try calculate(.sm07, ["heightCM": 100, "sittingHeightCM": 110]))
    }

    func testProjectedPointLengthsPreserveSideUnitAndPartialHipAvailability() throws {
        let points = ["shoulderX": 0.0, "shoulderY": 0, "elbowX": 3, "elbowY": 4, "wristX": 9, "wristY": 12, "scaleCMPerPixel": 2]
        let arm = try calculate(.sm08, points, text: ["side": "右", "calibrationStatus": "已校正且共面"])
        XCTAssertEqual(try number(arm, "upperLengthCM"), 10)
        XCTAssertEqual(try number(arm, "foreLengthCM"), 20)
        XCTAssertEqual(try number(arm, "foreUpperRatio"), 2)
        let pixelArm = try calculate(.sm08, points, text: ["side": "左", "calibrationStatus": "仅像素"])
        XCTAssertEqual(try number(pixelArm, "upperLengthPixels"), 5)
        XCTAssertFalse(pixelArm.values.contains { $0.unit == "cm" })
        var input = StaticMeasurementInput(values: ["kneeX": 0, "kneeY": 10, "ankleX": 0, "ankleY": 0], text: ["side": "右"], metadata: ["calibrationStatus": "仅像素", "pointSource": "manual", "modelRevision": "none", "imageID": "original", "imageWidth": "100", "imageHeight": "100"])
        let partial = try StaticMeasurementCalculator.calculate(feature: .sm09, input: input)
        XCTAssertEqual(partial.values.map(\.id), ["distLengthPixels"])
        XCTAssertEqual(partial.values[0].value, 10)
        input.values["hipX"] = 0
        XCTAssertThrowsError(try StaticMeasurementCalculator.calculate(feature: .sm09, input: input))
        input.values["hipY"] = 30
        let leg = try StaticMeasurementCalculator.calculate(feature: .sm09, input: input)
        XCTAssertEqual(try number(leg, "distProxRatio"), 0.5)
        var coincident = points
        coincident["elbowX"] = 0; coincident["elbowY"] = 0
        XCTAssertThrowsError(try calculate(.sm08, coincident, text: ["side": "右", "calibrationStatus": "已校正且共面"]))
    }

    func testHandFootAndGirthDefinitionsDoNotMixOrFillMissingInputs() throws {
        let hand = try calculate(.sm10, ["handLengthCM": 20, "handWidthCM": 8])
        XCTAssertEqual(try number(hand, "handAspectRatio"), 0.4)
        let foot = try calculate(.sm11, ["footLengthCM": 25, "footWidthCM": 10])
        XCTAssertEqual(try number(foot, "footAspectRatio"), 0.4)
        XCTAssertThrowsError(try calculate(.sm10, ["handLengthCM": 20, "handWidthCM": 8], text: ["side": "左"]))
        let girth = try calculate(.sm12, ["heightCM": 180, "waistGirthCM": 80, "hipGirthCM": 100], text: ["measurementPoints": "腰围髂嵴，臀围最大围度，自然呼气"])
        XCTAssertEqual(try number(girth, "waistHipGirthRatio"), 0.8)
        XCTAssertEqual(try number(girth, "relativeWaistGirth"), 80.0 / 180, accuracy: 0.000001)
        XCTAssertFalse(girth.values.contains { $0.id == "relativeChestGirth" })
        XCTAssertThrowsError(try calculate(.sm12, ["heightCM": 180], text: ["measurementPoints": "尚未测量"]))
        XCTAssertThrowsError(try calculate(.sm04, ["waistGirthCM": 80, "hipGirthCM": 100]))
    }

    func testOutlineCurveUsesUpwardYAndSpaceRatherThanTimeWithoutInterpolation() throws {
        let input = StaticMeasurementInput(values: ["headY": 100, "heightPixels": 100], series: ["heights": [80, 20, 50], "leftX": [-5, -20, -10], "rightX": [5, 20, 10]])
        let result = try StaticMeasurementCalculator.calculate(feature: .sm16, input: input)
        XCTAssertEqual(result.curve, [StaticCurvePoint(x: 0.2, y: 0.1), StaticCurvePoint(x: 0.5, y: 0.2), StaticCurvePoint(x: 0.8, y: 0.4)])
        var invalid = input
        invalid.series["rightX"] = [5]
        XCTAssertThrowsError(try StaticMeasurementCalculator.calculate(feature: .sm16, input: invalid))
        invalid = input; invalid.series["heights"] = [80, 80, 50]
        XCTAssertThrowsError(try StaticMeasurementCalculator.calculate(feature: .sm16, input: invalid))
        invalid = input; invalid.series["heights"] = [120, 20, 50]
        XCTAssertThrowsError(try StaticMeasurementCalculator.calculate(feature: .sm16, input: invalid))
    }

    func testAppearanceAnglesAndOffsetsRetainSignedDirection() throws {
        let shoulder = try calculate(.sr01, ["leftX": 20, "leftY": 0, "rightX": 0, "rightY": 10, "scaleCMPerPixel": 0.2], text: confirmed)
        XCTAssertEqual(try number(shoulder, "shoulderAngleDegrees"), atan2(10.0, 20) * 180 / .pi, accuracy: 0.000001)
        XCTAssertEqual(try number(shoulder, "shoulderHeightDifferenceCM"), 2)
        let negative = try calculate(.sr01, ["leftX": 0, "leftY": 10, "rightX": 20, "rightY": 0])
        XCTAssertLessThan(try number(negative, "shoulderAngleDegrees"), 0)
        XCTAssertFalse(negative.values.contains { $0.unit == "cm" })
        let ears = try calculate(.sr02, ["leftEarX": 0, "leftEarY": 0, "rightEarX": 20, "rightEarY": -2])
        XCTAssertEqual(try number(ears, "headAngleDegrees"), atan2(-2.0, 20) * 180 / .pi, accuracy: 0.000001)
        let outline = try calculate(.sr03, ["upperLeftX": 12, "upperRightX": 32, "waistLeftX": 10, "waistRightX": 30, "upperY": 60, "waistY": 20, "scaleCMPerPixel": 0.1], text: confirmed)
        XCTAssertEqual(try number(outline, "outlineOffsetPixels"), 2)
        XCTAssertEqual(try number(outline, "outlineAngleDegrees"), atan2(2.0, 40) * 180 / .pi, accuracy: 0.000001)
        XCTAssertEqual(try number(outline, "outlineOffsetCM"), 0.2)
        XCTAssertThrowsError(try calculate(.sr01, ["leftX": 0, "leftY": 0, "rightX": 0, "rightY": 0]))
    }

    func testBilateralGirthUsesEachSidesRepeatMeanAndMeanDenominator() throws {
        let input = StaticMeasurementInput(series: ["leftGirthsCM": [31, 33], "rightGirthsCM": [29, 30, 31]], text: ["site": "放松上臂固定中点"])
        let result = try StaticMeasurementCalculator.calculate(feature: .sr04, input: input)
        XCTAssertEqual(try number(result, "leftMeanCM"), 32)
        XCTAssertEqual(try number(result, "rightMeanCM"), 30)
        XCTAssertEqual(try number(result, "girthDifferenceCM"), 2)
        XCTAssertEqual(try number(result, "girthAsymmetryPercent"), 100.0 * 2 / 31, accuracy: 0.000001)
        var invalid = input; invalid.series["leftGirthsCM"] = [32]
        XCTAssertThrowsError(try StaticMeasurementCalculator.calculate(feature: .sr04, input: invalid))
    }

    func testHealthBackgroundKeepsUnknownDatesAndSubjectiveNRSWithoutRiskScore() throws {
        let now = Date(timeIntervalSince1970: 10 * 86400)
        let input = StaticMeasurementInput(values: ["eventCount": 2], text: ["site": "踝", "side": "右", "eventDescription": "自报不适，未确诊"], dates: ["lastEventDate": Date(timeIntervalSince1970: 3 * 86400), "returnToSportDate": Date(timeIntervalSince1970: 7 * 86400)])
        let result = try StaticMeasurementCalculator.calculate(feature: .sr05, input: input, now: now)
        XCTAssertEqual(try number(result, "daysSinceLastEvent"), 7)
        XCTAssertEqual(try number(result, "daysSinceReturnToSport"), 3)
        var unknown = input; unknown.dates = [:]
        XCTAssertEqual(try StaticMeasurementCalculator.calculate(feature: .sr05, input: unknown, now: now).values.map(\.id), ["eventCount"])
        var future = input; future.dates["lastEventDate"] = now.addingTimeInterval(86400)
        XCTAssertThrowsError(try StaticMeasurementCalculator.calculate(feature: .sr05, input: future, now: now))
        for nrs in [0.0, 10] {
            let pain = try calculate(.sr06, ["restingNRS": nrs], text: ["site": "腰", "side": "中线"])
            XCTAssertEqual(pain.values.map(\.id), ["restingNRS"])
            XCTAssertEqual(pain.values[0].value, nrs)
        }
        for invalid in [-1.0, 11, 1.5] { XCTAssertThrowsError(try calculate(.sr06, ["restingNRS": invalid], text: ["site": "膝", "side": "左"])) }
    }

    func testEllipseModelUsesIntegralNotCircumferenceOrMuscleClaims() throws {
        let circle = try calculate(.h01, ["widthCM": 20, "depthCM": 20], text: ["level": "同次同高度"])
        XCTAssertEqual(try number(circle, "ellipseEstimatedGirthCM"), 20 * .pi, accuracy: 0.000001)
        let ellipse = try calculate(.h01, ["widthCM": 20, "depthCM": 10], text: ["level": "同次同高度"])
        XCTAssertEqual(try number(ellipse, "ellipseEstimatedGirthCM"), 48.442241102738, accuracy: 0.000001)
    }

    func testUserTargetFormulaRequiresAllParametersAndUnitWeightSum() throws {
        let a = StaticTargetComponent(id: "a", title: "臂展", metricKey: "armSpanRatio", observed: 1.2, lowerBound: 1.0, upperBound: 1.1, scale: 0.1, weight: 0.25)
        let b = StaticTargetComponent(id: "b", title: "下肢", metricKey: "legBodyRatio", observed: 0.6, lowerBound: 0.5, upperBound: 0.7, scale: 0.1, weight: 0.75)
        let result = try StaticMeasurementCalculator.calculate(feature: .h02, input: StaticMeasurementInput(targets: [a, b]))
        XCTAssertEqual(try number(result, "targetMatch"), 100 * exp(-0.125), accuracy: 0.000001)
        XCTAssertEqual(try number(result, "targetDifference:a"), 1, accuracy: 0.000001)
        for change in ["weight", "scale", "bounds", "metric", "observed"] {
            var bad = a
            switch change {
            case "weight": bad.weight = 0.2
            case "scale": bad.scale = 0
            case "bounds": bad.upperBound = 0.9
            case "metric": bad.metricKey = "futureTalent"
            default: bad.observed = .nan
            }
            XCTAssertThrowsError(try StaticMeasurementCalculator.calculate(feature: .h02, input: StaticMeasurementInput(targets: [bad, b])))
        }
        XCTAssertThrowsError(try StaticMeasurementCalculator.calculate(feature: .h02, input: StaticMeasurementInput()))
    }

    func testPercentileCannotUseSyntheticSamplesAsReferenceLibrary() {
        XCTAssertThrowsError(try StaticMeasurementCalculator.calculate(feature: .h03, input: StaticMeasurementInput(values: ["observed": 1.1], series: ["reference": [1, 1.1, 1.2]]))) {
            XCTAssertEqual($0 as? StaticMeasurementError, .referenceLibraryUnavailable)
        }
    }

    func testQualityStatisticsUseSampleSDAndOnlyPositiveMeanLengthCV() throws {
        let lengths = StaticMeasurementInput(series: ["repeats": [10, 12, 14]], text: ["measurementType": "长度", "metricName": "独立重拍的腰宽"])
        let result = try StaticMeasurementCalculator.calculate(feature: .q02, input: lengths)
        XCTAssertEqual(try number(result, "mean"), 12)
        XCTAssertEqual(try number(result, "sampleSD"), 2)
        XCTAssertEqual(try number(result, "range"), 4)
        XCTAssertEqual(try number(result, "cvPercent"), 100.0 * 2 / 12, accuracy: 0.000001)
        let angles = StaticMeasurementInput(series: ["repeats": [-1, 0, 1]], text: ["measurementType": "角度", "metricName": "独立重拍的头部角"])
        let angleResult = try StaticMeasurementCalculator.calculate(feature: .q02, input: angles)
        XCTAssertEqual(try number(angleResult, "sampleSD"), 1)
        XCTAssertFalse(angleResult.values.contains { $0.id == "cvPercent" })
        var zero = lengths; zero.series["repeats"] = [0, 0, 0]
        XCTAssertThrowsError(try StaticMeasurementCalculator.calculate(feature: .q02, input: zero))
        var negative = lengths; negative.series["repeats"] = [-1, 1, 3]
        XCTAssertThrowsError(try StaticMeasurementCalculator.calculate(feature: .q02, input: negative))
        var missing = lengths; missing.series["repeats"] = [10, 12]
        XCTAssertThrowsError(try StaticMeasurementCalculator.calculate(feature: .q02, input: missing))
    }

    func testInvalidRawNumbersAndMetadataRoundTripWithoutFabricatingResults() throws {
        for invalid in [0.0, -1, .nan, .infinity] {
            XCTAssertThrowsError(try calculate(.sm02, ["armSpanCM": invalid, "heightCM": 178]))
        }
        let input = StaticMeasurementInput(values: ["armSpanCM": 184, "heightCM": 178], text: ["pointSource": "manual", "customContext": "保留"], metadata: ["imageID": "local-image", "modelRevision": "not-used"])
        let result = try StaticMeasurementCalculator.calculate(feature: .sm02, input: input)
        let record = StaticMeasurementRecord(feature: .sm02, input: input, result: result)
        let decoded = try JSONDecoder().decode(StaticMeasurementRecord.self, from: JSONEncoder().encode(record))
        XCTAssertEqual(record, decoded)
        XCTAssertEqual(decoded.origin, .manual)
        XCTAssertEqual(decoded.input.metadata["imageID"], "local-image")
        XCTAssertEqual(decoded.input.text["customContext"], "保留")
        XCTAssertThrowsError(try calculate(.sm02, ["armSpanCM": 184, "heightCM": 178, "madeUpScore": 100]))
    }
}
