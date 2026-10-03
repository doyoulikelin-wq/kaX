import XCTest
@testable import KaX

@MainActor final class StaticStoreTests: XCTestCase {
    private func record(_ feature: StaticFeatureID = .sm02, input: StaticMeasurementInput? = nil) -> StaticMeasurementRecord {
        StaticMeasurementRecord(feature: feature, input: input ?? StaticMeasurementInput(values: ["armSpanCM": 180, "heightCM": 175], text: ["inputMode": "manual"]), result: StaticMeasurementResult(values: []))
    }
    func testOldSnapshotLoadsWithoutCatalogOrSourceLinks() throws {
        let data = try LocalAppRepository.encode(SampleData.emptySnapshot)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "staticMeasurements"); json.removeValue(forKey: "rankingMeasurements")
        let decoder = JSONDecoder()
        let old = try decoder.decode(AppSnapshot.self, from: JSONSerialization.data(withJSONObject: json))
        let store = AppStore(repository: StaticTestRepository(old), useDemoData: false)
        XCTAssertTrue(store.staticMeasurements.isEmpty)
    }
    func testRecalculatesRatherThanTrustingResultAndRoundTrips() throws {
        let repo = StaticTestRepository(); let store = AppStore(repository: repo, useDemoData: false)
        var entry = record(); entry.result = StaticMeasurementResult(values: [StaticResultValue(id: "fraud", title: "Bad", value: 999, unit: "%")])
        store.saveStaticMeasurement(entry)
        XCTAssertNil(store.persistenceError)
        XCTAssertFalse(store.staticMeasurements[0].result.values.contains { $0.id == "fraud" })
        XCTAssertEqual(store.staticMeasurements[0].result.values.first { $0.id == "armSpanRatio" }?.value ?? 0, 180.0 / 175, accuracy: 0.0001)
        let reloaded = AppStore(repository: repo, useDemoData: false)
        XCTAssertEqual(reloaded.staticMeasurements, store.staticMeasurements)
        let data = try XCTUnwrap(store.exportData()); XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("staticMeasurements"))
    }
    func testAtomicRollbackIncludesDerivedRanking() {
        let repo = StaticTestRepository(); let store = AppStore(repository: repo, useDemoData: false)
        var entry = record(); entry.input.text["rankingProtocolConfirmed"] = "true"
        repo.fail = true; store.saveStaticMeasurement(entry)
        XCTAssertTrue(store.staticMeasurements.isEmpty); XCTAssertTrue(store.rankingMeasurements.isEmpty); XCTAssertNotNil(store.persistenceError)
    }
    func testManualProtocolOptInAndUpsertDoNotDuplicateRank() {
        let store = AppStore(repository: StaticTestRepository(), useDemoData: false)
        var entry = record(); store.saveStaticMeasurement(entry)
        XCTAssertTrue(store.rankingMeasurements.isEmpty)
        entry.input.text["rankingProtocolConfirmed"] = "true"; store.saveStaticMeasurement(entry)
        XCTAssertEqual(store.rankingMeasurements.count, 1)
        XCTAssertEqual(store.rankingMeasurements.first?.sourceRecordID, entry.id)
        entry.input.values["armSpanCM"] = 182; store.saveStaticMeasurement(entry)
        XCTAssertEqual(store.staticMeasurements.count, 1); XCTAssertEqual(store.rankingMeasurements.count, 1)
        entry.input.text["rankingProtocolConfirmed"] = "false"; store.saveStaticMeasurement(entry)
        XCTAssertTrue(store.rankingMeasurements.isEmpty)
    }
    func testPhotoCannotEnterManualRankEvenWithFlag() {
        let store = AppStore(repository: StaticTestRepository(), useDemoData: false)
        var entry = record(); entry.input.text = ["inputMode": "photo", "rankingProtocolConfirmed": "true"]
        store.saveStaticMeasurement(entry)
        XCTAssertEqual(store.staticMeasurements.count, 1); XCTAssertTrue(store.rankingMeasurements.isEmpty)
    }
    func testInvalidInputReferenceLibraryAndIdentityAreRejected() {
        let store = AppStore(repository: StaticTestRepository(), useDemoData: false)
        var entry = record(); entry.input.values["heightCM"] = .nan; store.saveStaticMeasurement(entry)
        XCTAssertTrue(store.staticMeasurements.isEmpty)
        store.saveStaticMeasurement(record(.h03, input: StaticMeasurementInput())); XCTAssertTrue(store.staticMeasurements.isEmpty)
        entry = record(); store.saveStaticMeasurement(entry)
        var other = record(.sm13, input: StaticMeasurementInput(values: ["weightKG": 70, "heightCM": 175])); other.id = entry.id
        store.saveStaticMeasurement(other); XCTAssertEqual(store.staticMeasurements.first?.feature, .sm02)
        entry.origin = .device; store.saveStaticMeasurement(entry); XCTAssertNotNil(store.persistenceError)
    }
    func testSourceLinkOptionalForOldRankingJSON() throws {
        let entry = RankingMeasurement(personID: "me", metric: .armSpanRatio, values: ["armSpanCM":180,"heightCM":175], origin:.manual)
        let data = try JSONEncoder().encode(entry)
        XCTAssertNil(try JSONDecoder().decode(RankingMeasurement.self, from:data).sourceRecordID)
    }
}

private final class StaticTestRepository: AppRepository {
    var saved: AppSnapshot?
    var fail = false
    init(_ initial: AppSnapshot? = nil) { saved = initial }
    func load() throws -> AppSnapshot? { saved }
    func save(_ snapshot: AppSnapshot) throws {
        if fail { throw CocoaError(.fileWriteNoPermission) }
        saved = snapshot
    }
}

final class StaticPhotoGeometryTests: XCTestCase {
    func testCoordinateTransformAndBounds() {
        let point = StaticPhotoGeometry.pointInImage(location: CGPoint(x:50,y:50), displaySize:CGSize(width:100,height:200), imageSize:CGSize(width:600,height:1200))
        XCTAssertEqual(point, CGPoint(x:300,y:900))
        XCTAssertNil(StaticPhotoGeometry.pointInImage(location:CGPoint(x:-1,y:0),displaySize:CGSize(width:100,height:200),imageSize:CGSize(width:600,height:1200)))
    }
    func testCalibratedDistanceAndPixelsAreDistinct() throws {
        let points = ["referenceA":CGPoint(x:0,y:0),"referenceB":CGPoint(x:0,y:200),"start":CGPoint(x:100,y:0),"end":CGPoint(x:100,y:400)]
        let input = try StaticPhotoGeometry.input(feature:.q01,points:points,referenceLength:20,samePlane:true,corrected:true,level:false,side:"右")
        let result = try StaticMeasurementCalculator.calculate(feature:.q01,input:input)
        XCTAssertEqual(result.values.first { $0.id == "lengthCM" }?.value,40)
        let pixels = try StaticPhotoGeometry.input(feature:.q01,points:points,referenceLength:nil,samePlane:false,corrected:false,level:false,side:"右")
        let pixelResult = try StaticMeasurementCalculator.calculate(feature:.q01,input:pixels)
        XCTAssertEqual(pixelResult.values.map(\.unit), ["px"])
        XCTAssertThrowsError(try StaticPhotoGeometry.input(feature:.q01,points:points,referenceLength:20,samePlane:false,corrected:true,level:false,side:"右"))
    }
    func testLevelAndMissingPointsCannotBeInvented() {
        XCTAssertThrowsError(try StaticPhotoGeometry.input(feature:.sm01,points:[:],referenceLength:nil,samePlane:false,corrected:false,level:false,side:"右"))
        XCTAssertThrowsError(try StaticPhotoGeometry.input(feature:.sm08,points:[:],referenceLength:nil,samePlane:false,corrected:false,level:false,side:"右"))
    }
    func testShoulderSignedDifference() throws {
        let input = try StaticPhotoGeometry.input(feature:.sr01,points:["left":CGPoint(x:100,y:200),"right":CGPoint(x:0,y:190)],referenceLength:nil,samePlane:false,corrected:false,level:true,side:"右")
        let result = try StaticMeasurementCalculator.calculate(feature:.sr01,input:input)
        XCTAssertLessThan(try XCTUnwrap(result.values.first?.value),0)
        XCTAssertFalse(result.values.contains { $0.unit == "cm" })
    }
}
