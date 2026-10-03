import XCTest
@testable import KaX

final class ScoreCalculatorTests: XCTestCase {
    func testEpleyBoundariesAndSingleRep() throws {
        XCTAssertEqual(try ScoreCalculator.estimatedOneRepMax(weight: 80, repetitions: 1), 80)
        XCTAssertEqual(try ScoreCalculator.estimatedOneRepMax(weight: 60, repetitions: 30), 120)
        XCTAssertEqual(try ScoreCalculator.estimatedOneRepMax(weight: 70, repetitions: 5), 81.6666667, accuracy: 0.000001)
    }

    func testInvalidStrengthInputsAndOverflow() {
        for weight in [0.0, -1, .nan, .infinity] {
            XCTAssertThrowsError(try ScoreCalculator.estimatedOneRepMax(weight: weight, repetitions: 5))
        }
        XCTAssertThrowsError(try ScoreCalculator.estimatedOneRepMax(weight: 60, repetitions: 0))
        XCTAssertThrowsError(try ScoreCalculator.estimatedOneRepMax(weight: 60, repetitions: 31))
        XCTAssertThrowsError(try ScoreCalculator.estimatedOneRepMax(weight: .greatestFiniteMagnitude, repetitions: 30))
    }

    func testRatiosAndInvalidDenominators() throws {
        XCTAssertEqual(try ScoreCalculator.relativeStrength(oneRepMax: 90, bodyWeight: 75), 1.2, accuracy: 0.000001)
        XCTAssertEqual(try ScoreCalculator.armSpanRatio(armSpanCM: 184, heightCM: 178), 184.0 / 178, accuracy: 0.000001)
        for invalid in [0.0, -2, .nan, .infinity] {
            XCTAssertThrowsError(try ScoreCalculator.relativeStrength(oneRepMax: 90, bodyWeight: invalid))
            XCTAssertThrowsError(try ScoreCalculator.armSpanRatio(armSpanCM: 184, heightCM: invalid))
            XCTAssertThrowsError(try ScoreCalculator.armSpanRatio(armSpanCM: invalid, heightCM: 178))
        }
    }
}

final class LocalAppRepositoryTests: XCTestCase {
    private var directory: URL!
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }

    func testAtomicSaveCreatesDirectoriesAndRoundTrips() throws {
        let destination = directory.appendingPathComponent("nested/snapshot.json")
        let repository = LocalAppRepository(url: destination)
        XCTAssertNil(try repository.load())
        try repository.save(SampleData.snapshot)
        XCTAssertEqual(try repository.load(), SampleData.snapshot)
        var update = SampleData.snapshot
        update.profile.name = "更新后的名字"
        update.posts.removeLast()
        try repository.save(update)
        XCTAssertEqual(try repository.load(), update)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: destination.deletingLastPathComponent().path), ["snapshot.json"])
    }

    func testEncodingFailurePreservesPreviousAtomicSnapshot() throws {
        let repository = LocalAppRepository(url: directory.appendingPathComponent("snapshot.json"))
        try repository.save(SampleData.snapshot)
        let previous = try Data(contentsOf: repository.url)
        var invalid = SampleData.snapshot
        invalid.profile.heightCM = .nan
        XCTAssertThrowsError(try repository.save(invalid))
        XCTAssertEqual(try Data(contentsOf: repository.url), previous)
        XCTAssertEqual(try repository.load(), SampleData.snapshot)
    }

    func testCorruptionAndUnsupportedVersionAreVisible() throws {
        let repository = LocalAppRepository(url: directory.appendingPathComponent("snapshot.json"))
        try Data("invalid JSON".utf8).write(to: repository.url)
        XCTAssertThrowsError(try repository.load())
        var future = SampleData.snapshot
        future.schemaVersion = 2
        try repository.save(future)
        XCTAssertThrowsError(try repository.load()) { error in
            guard case RepositoryError.unsupportedVersion(2) = error else { return XCTFail("Expected schema error") }
        }
    }
}

@MainActor final class AppStoreTests: XCTestCase {
    func testLikesCommentsAndFollowingPersistAcrossLaunches() throws {
        let repository = MemoryRepository(snapshot: SampleData.snapshot)
        let store = AppStore(repository: repository)
        let post = store.posts[0]
        store.toggleLike(postID: post.id)
        XCTAssertTrue(store.posts[0].isLiked)
        XCTAssertEqual(store.posts[0].likes, post.likes + 1)
        store.toggleLike(postID: post.id)
        XCTAssertFalse(store.posts[0].isLiked)
        XCTAssertEqual(store.posts[0].likes, post.likes)
        store.addComment(postID: post.id, text: "  一起记录  \n")
        XCTAssertEqual(store.posts[0].comments.last?.text, "一起记录")
        let count = store.posts[0].comments.count
        store.addComment(postID: post.id, text: " \n ")
        XCTAssertEqual(store.posts[0].comments.count, count)
        store.toggleFollow(personID: "chen")
        XCTAssertTrue(store.people.first(where: { $0.id == "chen" })!.isFollowing)
        let reopened = AppStore(repository: repository)
        XCTAssertEqual(reopened.posts, store.posts)
        XCTAssertEqual(reopened.people, store.people)
    }

    func testEveryMutationRollsBackWhenSavingFails() {
        let repository = MemoryRepository(snapshot: SampleData.snapshot)
        let store = AppStore(repository: repository)
        repository.failSaving = true
        let original = SampleData.snapshot
        var profile = store.profile
        profile.name = "没有保存的名字"
        store.saveProfile(profile)
        store.toggleLike(postID: original.posts[0].id)
        store.toggleFollow(personID: original.people[0].id)
        store.addComment(postID: original.posts[0].id, text: "未保存评论")
        store.addRecord(MeasurementRecord(kind: .strength, title: "卧推", value: 80, unit: "kg", secondaryValue: 5, origin: .manual))
        store.publish(caption: "未保存动态", recordID: original.records[0].id)
        store.resetDemo()
        XCTAssertEqual(store.profile, original.profile)
        XCTAssertEqual(store.records, original.records)
        XCTAssertEqual(store.posts, original.posts)
        XCTAssertEqual(store.people, original.people)
        XCTAssertNotNil(store.persistenceError)
        XCTAssertEqual(repository.snapshot, original)
        repository.failSaving = false
        store.saveProfile(profile)
        XCTAssertEqual(store.profile.name, profile.name)
        XCTAssertNil(store.persistenceError)
    }

    func testBodyProfileAndRecordCommitInOneSaveOrNeither() {
        let repository = MemoryRepository(snapshot: SampleData.snapshot)
        let store = AppStore(repository: repository)
        var profile = store.profile
        profile.armSpanCM = 186
        let record = MeasurementRecord(kind: .body, title: "臂展", value: 186, unit: "cm", secondaryValue: profile.heightCM, origin: .manual)
        repository.failSaving = true
        store.saveBodyMeasurement(profile: profile, record: record)
        XCTAssertEqual(store.profile, SampleData.profile)
        XCTAssertFalse(store.records.contains(where: { $0.id == record.id }))
        repository.failSaving = false
        let previousSaves = repository.saveCount
        store.saveBodyMeasurement(profile: profile, record: record)
        XCTAssertEqual(repository.saveCount, previousSaves + 1)
        XCTAssertEqual(repository.snapshot?.profile.armSpanCM, 186)
        XCTAssertTrue(repository.snapshot!.records.contains(where: { $0.id == record.id }))
    }

    func testCorruptLoadDoesNotOverwriteUntilExplicitReset() {
        let repository = MemoryRepository(snapshot: SampleData.snapshot)
        repository.failLoading = true
        let store = AppStore(repository: repository)
        XCTAssertNotNil(store.persistenceError)
        store.toggleLike(postID: store.posts[0].id)
        XCTAssertEqual(repository.saveCount, 0)
        XCTAssertEqual(repository.snapshot, SampleData.snapshot)
        XCTAssertNil(store.exportData())
        XCTAssertNotNil(store.persistenceError)
        store.resetDemo()
        XCTAssertEqual(repository.saveCount, 1)
        XCTAssertNil(store.persistenceError)
    }

    func testStrengthBaselineRejectsInvalidRepeatsWithoutWriting() {
        let repository = MemoryRepository(snapshot: SampleData.snapshot)
        let store = AppStore(repository: repository)
        for repetitions in [0.0, 31, 1.5, .nan, .infinity] {
            let invalid = MeasurementRecord(kind: .strength, title: "卧推", value: 60, unit: "kg", secondaryValue: repetitions, origin: .manual)
            store.addRecord(invalid)
            XCTAssertEqual(store.records, SampleData.records)
            XCTAssertEqual(repository.saveCount, 0)
            XCTAssertNotNil(store.persistenceError)
        }
        let boundary = MeasurementRecord(kind: .strength, title: "卧推", value: 60, unit: "kg", secondaryValue: 30, origin: .manual)
        store.addRecord(boundary)
        XCTAssertEqual(repository.saveCount, 1)
        XCTAssertEqual(store.records[0], boundary)
        XCTAssertNil(store.persistenceError)
    }

    func testExportReportsEncodingFailure() {
        var invalid = SampleData.snapshot
        invalid.profile.heightCM = .nan
        let store = AppStore(repository: MemoryRepository(snapshot: invalid))
        XCTAssertNil(store.exportData())
        XCTAssertNotNil(store.persistenceError)
    }

    func testLikeCountsCannotOverflowOrBecomeNegative() {
        var fixture = SampleData.snapshot
        fixture.posts[0].likes = Int.max
        fixture.posts[1].likes = 0
        fixture.posts[1].isLiked = true
        let store = AppStore(repository: MemoryRepository(snapshot: fixture))
        store.toggleLike(postID: fixture.posts[0].id)
        XCTAssertEqual(store.posts[0].likes, Int.max)
        XCTAssertTrue(store.posts[0].isLiked)
        store.toggleLike(postID: fixture.posts[1].id)
        XCTAssertEqual(store.posts[1].likes, 0)
        XCTAssertFalse(store.posts[1].isLiked)
    }

    func testLatestLegacyRecordsUseDates() {
        let store = AppStore(repository: MemoryRepository(snapshot: SampleData.snapshot))
        let old = MeasurementRecord(date: SampleData.referenceDate.addingTimeInterval(-2_000_000), kind: .strength, title: "卧推", value: 100, unit: "kg", secondaryValue: 1, origin: .manual)
        store.addRecord(old)
        XCTAssertEqual(store.latestStrength?.id, SampleData.records[1].id)
    }

    func testProfileBoundsAndEmptyInitialization() {
        let repository = MemoryRepository(snapshot: SampleData.snapshot)
        let store = AppStore(repository: repository)
        var invalid = store.profile
        invalid.heightCM = 0
        store.saveProfile(invalid)
        XCTAssertEqual(store.profile, SampleData.profile)
        invalid = store.profile
        invalid.name = String(repeating: "字", count: 25)
        store.saveProfile(invalid)
        XCTAssertEqual(store.profile, SampleData.profile)
        invalid = store.profile
        invalid.bio = String(repeating: "字", count: 121)
        store.saveProfile(invalid)
        XCTAssertEqual(store.profile, SampleData.profile)
        invalid = store.profile
        invalid.weightKG = 501
        store.saveProfile(invalid)
        XCTAssertEqual(store.profile, SampleData.profile)
        var valid = store.profile
        valid.heightCM = 50; valid.weightKG = 20; valid.armSpanCM = 300; valid.waistCM = 30
        valid.name = String(repeating: "字", count: 24)
        valid.bio = String(repeating: "字", count: 120)
        store.saveProfile(valid)
        XCTAssertEqual(store.profile, valid)
        XCTAssertNil(store.persistenceError)

        let emptyStore = AppStore(repository: MemoryRepository(snapshot: nil), useDemoData: false)
        var emptyProfile = emptyStore.profile
        emptyProfile.name = "还未测量"
        emptyStore.saveProfile(emptyProfile)
        XCTAssertEqual(emptyStore.profile.name, "还未测量")
        XCTAssertEqual(emptyStore.profile.heightCM, 0)
        XCTAssertNil(emptyStore.persistenceError)
    }

    func testPublishRetainsMeasurementOriginAndExportRoundTrips() throws {
        let repository = MemoryRepository(snapshot: SampleData.snapshot)
        let store = AppStore(repository: repository)
        store.publish(caption: "", recordID: SampleData.records[0].id)
        XCTAssertEqual(store.posts[0].origin, .demo)
        XCTAssertEqual(store.posts[0].authorID, store.profile.id)
        XCTAssertEqual(store.posts[0].likes, 0)
        let data = try XCTUnwrap(store.exportData())
        let exported = try JSONDecoder().decode(AppSnapshot.self, from: data)
        XCTAssertEqual(exported, repository.snapshot)
        XCTAssertTrue(SampleData.records.allSatisfy { $0.origin == .demo })
        XCTAssertTrue(SampleData.posts.allSatisfy { $0.origin == .demo })
    }

    func testPublishStrengthRetainsRepetitionsAndSource() {
        let store = AppStore(repository: MemoryRepository(snapshot: SampleData.snapshot))
        let demo = SampleData.records[1]
        store.publish(caption: "演示基准", recordID: demo.id)
        XCTAssertEqual(store.posts[0].origin, .demo)
        XCTAssertEqual(store.posts[0].metricValue, "70")
        XCTAssertEqual(store.posts[0].metricUnit, "kg × 5")

        let manual = MeasurementRecord(kind: .strength, title: "卧推", value: 80, unit: "kg", secondaryValue: 8, origin: .manual)
        store.addRecord(manual)
        store.publish(caption: "手动基准", recordID: manual.id)
        XCTAssertEqual(store.posts[0].origin, .manual)
        XCTAssertEqual(store.posts[0].metricValue, "80")
        XCTAssertEqual(store.posts[0].metricUnit, "kg × 8")
        XCTAssertEqual(store.records.first(where: { $0.id == manual.id })?.unit, "kg")

        let singleMaximum = MeasurementRecord(kind: .strength, title: "卧推", value: 90, unit: "kg", origin: .manual)
        store.addRecord(singleMaximum)
        store.publish(caption: "已知单次最大重量", recordID: singleMaximum.id)
        XCTAssertEqual(store.posts[0].origin, .manual)
        XCTAssertEqual(store.posts[0].metricUnit, "kg")
    }
}

final class RankingMetricTests: XCTestCase {
    func testAllEightStaticFormulasUseTheirOwnRawDimensions() throws {
        let examples: [(RankingMetric, [String: Double], Double)] = [
            (.armSpanRatio, ["armSpanCM": 184, "heightCM": 178], 184.0 / 178),
            (.relativeShoulderWidth, ["shoulderWidthCM": 46, "heightCM": 178], 46.0 / 178),
            (.legBodyRatio, ["heightCM": 178, "sittingHeightCM": 92], 86.0 / 178),
            (.shoulderWaistWidthRatio, ["shoulderWidthCM": 46, "waistWidthCM": 28], 46.0 / 28),
            (.waistHipWidthRatio, ["waistWidthCM": 28, "hipWidthCM": 35], 0.8),
            (.waistHipGirthRatio, ["waistGirthCM": 78, "hipGirthCM": 96], 78.0 / 96),
            (.handAspectRatio, ["handWidthCM": 8.5, "handLengthCM": 19], 8.5 / 19),
            (.footAspectRatio, ["footWidthCM": 10, "footLengthCM": 26], 10.0 / 26)
        ]
        XCTAssertEqual(Set(examples.map { $0.0 }), Set(RankingMetric.allCases))
        for (metric, values, expected) in examples {
            XCTAssertEqual(try metric.calculatedValue(from: values), expected, accuracy: 0.000001)
            XCTAssertEqual(metric.displayPrecision, 2)
        }
    }

    func testMissingInvalidAndDifferentMeasurementDefinitionsAreRejected() {
        for invalid in [0.0, -1, .nan, .infinity, 301] {
            XCTAssertThrowsError(try RankingMetric.armSpanRatio.calculatedValue(from: ["armSpanCM": invalid, "heightCM": 178]))
        }
        XCTAssertThrowsError(try RankingMetric.armSpanRatio.calculatedValue(from: ["armSpanCM": 184]))
        XCTAssertThrowsError(try RankingMetric.armSpanRatio.calculatedValue(from: ["armSpanCM": 184, "heightCM": 178, "weightKG": 72]))
        XCTAssertThrowsError(try RankingMetric.legBodyRatio.calculatedValue(from: ["heightCM": 100, "sittingHeightCM": 100]))
        XCTAssertThrowsError(try RankingMetric.handAspectRatio.calculatedValue(from: ["handWidthCM": 10, "handLengthCM": 9]))
        XCTAssertThrowsError(try RankingMetric.footAspectRatio.calculatedValue(from: ["footWidthCM": 20, "footLengthCM": 19]))
        XCTAssertThrowsError(try RankingMetric.waistHipWidthRatio.calculatedValue(from: ["waistGirthCM": 78, "hipGirthCM": 96]))
        XCTAssertThrowsError(try RankingMetric.waistHipGirthRatio.calculatedValue(from: ["waistWidthCM": 28, "hipWidthCM": 35]))
    }

    func testSampleDimensionsAreExplicitDemoInputsForEveryMetricAndPerson() throws {
        let expectedPeople = Set(SampleData.people.map(\.id) + [SampleData.profile.id])
        let samples = RankingSampleData.measurements
        XCTAssertEqual(samples.count, expectedPeople.count * RankingMetric.allCases.count)
        XCTAssertEqual(Set(samples.map(\.personID)), expectedPeople)
        for id in expectedPeople {
            XCTAssertEqual(Set(samples.filter { $0.personID == id }.map(\.metric)), Set(RankingMetric.allCases))
        }
        for sample in samples {
            XCTAssertEqual(sample.origin, .demo)
            XCTAssertEqual(sample.protocolID, sample.metric.protocolID)
            XCTAssertGreaterThan(try sample.calculatedValue(), 0)
        }
    }
}

@MainActor final class EvidenceRankingTests: XCTestCase {
    private func measurement(person: String = "kax_me", span: Double, height: Double = 100, date: TimeInterval = 100, id: UUID = UUID(), origin: DataOrigin = .manual) -> RankingMeasurement {
        RankingMeasurement(id: id, personID: person, metric: .armSpanRatio, values: ["armSpanCM": span, "heightCM": height], date: Date(timeIntervalSince1970: date), origin: origin)
    }

    func testRanksDisplayedTiesAndFiltersFollowingWithoutLosingCurrentUser() {
        var fixture = SampleData.snapshot
        fixture.people = [SampleData.people[0], SampleData.people[1]]
        fixture.people[1].isFollowing = false
        fixture.rankingMeasurements = [measurement(span: 103.4), measurement(person: "lin", span: 103.1), measurement(person: "yu", span: 102)]
        let store = AppStore(repository: MemoryRepository(snapshot: fixture))
        let all = store.rankingEntries(for: .armSpanRatio)
        XCTAssertEqual(all.map(\.id), ["kax_me", "lin", "yu"])
        XCTAssertEqual(all.map(\.position), [1, 1, 3])
        XCTAssertEqual(all.map { RankingMetric.armSpanRatio.formattedValue($0.value) }, ["1.03", "1.03", "1.02"])
        XCTAssertEqual(store.rankingEntries(for: .armSpanRatio).map(\.id), all.map(\.id))
        let following = store.rankingEntries(for: .armSpanRatio, followingOnly: true)
        XCTAssertEqual(following.map(\.id), ["kax_me", "lin"])
        XCTAssertEqual(following.map(\.position), [1, 1])
        store.toggleFollow(personID: "lin")
        XCTAssertEqual(store.rankingEntries(for: .armSpanRatio, followingOnly: true).map(\.id), ["kax_me"])
        XCTAssertEqual(store.rankingEntries(for: .armSpanRatio).map(\.id), all.map(\.id))
    }

    func testLatestMatchingProtocolWinsAndDamagedLatestDoesNotReviveOlderResult() throws {
        let older = measurement(span: 120, date: 100)
        let newer = measurement(span: 101, date: 200)
        var otherProtocol = measurement(span: 130, date: 300)
        otherProtocol.protocolID = "another.definition.v1"
        var fixture = SampleData.snapshot
        fixture.rankingMeasurements = [older, newer, otherProtocol]
        var store = AppStore(repository: MemoryRepository(snapshot: fixture))
        let mine = try XCTUnwrap(store.rankingEntries(for: .armSpanRatio).first(where: \.isCurrentUser))
        XCTAssertEqual(mine.value, 1.01)
        XCTAssertEqual(mine.measurement.id, newer.id)
        var damaged = measurement(span: 140, date: 400)
        damaged.values.removeValue(forKey: "heightCM")
        fixture.rankingMeasurements!.append(damaged)
        store = AppStore(repository: MemoryRepository(snapshot: fixture))
        XCTAssertFalse(store.rankingEntries(for: .armSpanRatio).contains(where: \.isCurrentUser))
        XCTAssertEqual(store.latestRankingMeasurement(for: .armSpanRatio)?.id, damaged.id)
    }

    func testSameDateLatestChoiceIsStableByRecordID() throws {
        let firstID = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
        let lastID = UUID(uuidString: "00000000-0000-4000-8000-000000000002")!
        let first = measurement(span: 120, id: firstID)
        let last = measurement(span: 101, id: lastID)
        var fixture = SampleData.snapshot
        for records in [[first, last], [last, first]] {
            fixture.rankingMeasurements = records
            let store = AppStore(repository: MemoryRepository(snapshot: fixture))
            XCTAssertEqual(store.latestRankingMeasurement(for: .armSpanRatio)?.id, lastID)
            XCTAssertEqual(try XCTUnwrap(store.rankingEntries(for: .armSpanRatio).first).value, 1.01)
        }
    }

    func testManualMeasurementsNeverFillMissingInputsFromDemoProfileOrPreviousSamples() throws {
        var fixture = SampleData.snapshot
        var incomplete = measurement(span: 200, date: SampleData.referenceDate.timeIntervalSince1970 + 1)
        incomplete.values.removeValue(forKey: "heightCM")
        fixture.rankingMeasurements!.append(incomplete)
        let store = AppStore(repository: MemoryRepository(snapshot: fixture))
        XCTAssertFalse(store.rankingEntries(for: .armSpanRatio).contains(where: \.isCurrentUser))
        let own = measurement(span: 200, height: 180, date: SampleData.referenceDate.timeIntervalSince1970 + 2)
        store.saveRankingMeasurement(own)
        let mine = try XCTUnwrap(store.rankingEntries(for: .armSpanRatio).first(where: \.isCurrentUser))
        XCTAssertEqual(mine.value, 200.0 / 180, accuracy: 0.000001)
        XCTAssertEqual(mine.measurement.origin, .manual)
        XCTAssertEqual(mine.measurement.values, own.values)
        var profile = store.profile
        profile.heightCM = 190
        store.saveProfile(profile)
        XCTAssertEqual(store.rankingEntries(for: .armSpanRatio).first(where: \.isCurrentUser)?.value, mine.value)
    }

    func testInvalidUnknownProtocolForeignAndDeviceRecordsNeverWrite() {
        let repository = MemoryRepository(snapshot: SampleData.snapshot)
        let store = AppStore(repository: repository)
        let original = store.rankingMeasurements
        var missing = measurement(span: 184)
        missing.values.removeValue(forKey: "heightCM")
        var protocolMismatch = measurement(span: 184)
        protocolMismatch.protocolID = "unknown"
        var invalidDate = measurement(span: 184)
        invalidDate.date = Date(timeIntervalSince1970: .infinity)
        let collision = measurement(span: 184, id: RankingSampleData.measurements.first(where: { $0.personID == "lin" })!.id)
        for record in [missing, protocolMismatch, invalidDate, measurement(person: "lin", span: 184), measurement(span: 0), measurement(span: 184, origin: .device), collision] {
            store.saveRankingMeasurement(record)
            XCTAssertEqual(store.rankingMeasurements, original)
            XCTAssertEqual(repository.saveCount, 0)
            XCTAssertNotNil(store.persistenceError)
        }
    }

    func testRankingSaveFailureRollsBackAndSuccessfulSaveExportsRawDataWithoutDeletingHistory() throws {
        let repository = MemoryRepository(snapshot: SampleData.snapshot)
        let store = AppStore(repository: repository)
        let original = store.rankingMeasurements
        let record = measurement(span: 200, height: 180, date: SampleData.referenceDate.timeIntervalSince1970 + 1)
        repository.failSaving = true
        store.saveRankingMeasurement(record)
        XCTAssertEqual(store.rankingMeasurements, original)
        XCTAssertEqual(repository.snapshot, SampleData.snapshot)
        XCTAssertNotNil(store.persistenceError)
        repository.failSaving = false
        store.saveRankingMeasurement(record)
        XCTAssertEqual(repository.saveCount, 1)
        XCTAssertEqual(store.latestRankingMeasurement(for: .armSpanRatio), record)
        XCTAssertEqual(store.records, SampleData.records)
        XCTAssertNil(store.persistenceError)
        let decoded = try JSONDecoder().decode(AppSnapshot.self, from: XCTUnwrap(store.exportData()))
        XCTAssertEqual(decoded, repository.snapshot)
        XCTAssertTrue(decoded.rankingMeasurements!.contains(record))
        let reopened = AppStore(repository: repository)
        XCTAssertEqual(reopened.rankingEntries(for: .armSpanRatio), store.rankingEntries(for: .armSpanRatio))
        store.resetDemo()
        XCTAssertEqual(store.rankingMeasurements, RankingSampleData.measurements)
    }

    func testLegacyJSONMissingRankingKeyPreservesOldDataAndDoesNotInventPersonalProtocol() throws {
        var old = SampleData.snapshot
        old.rankingMeasurements = nil
        old.records[0].origin = .manual
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: LocalAppRepository.encode(old)) as? [String: Any])
        json.removeValue(forKey: "rankingMeasurements")
        let legacy = try JSONDecoder().decode(AppSnapshot.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(legacy.rankingMeasurements)
        XCTAssertEqual(legacy.records, old.records)
        XCTAssertEqual(legacy.profile, old.profile)
        let store = AppStore(repository: MemoryRepository(snapshot: legacy))
        XCTAssertFalse(store.rankingEntries(for: .armSpanRatio).contains(where: \.isCurrentUser))
        XCTAssertTrue(store.rankingMeasurements.allSatisfy { $0.personID != store.profile.id && $0.origin == .demo })
        XCTAssertEqual(store.records, old.records)
        XCTAssertTrue(AppStore(repository: MemoryRepository(snapshot: legacy), useDemoData: false).rankingMeasurements.isEmpty)
        let empty = AppStore(repository: MemoryRepository(snapshot: nil), useDemoData: false)
        XCTAssertTrue(empty.rankingEntries(for: .armSpanRatio).isEmpty)
    }
}

final class MeasurementDeviceTests: XCTestCase {
    func testDemoWaveformIsDeterministicAndCompletes() async throws {
        let device = DemoMeasurementDevice(sampleCount: 8, sampleInterval: 0.025, realtime: false)
        try await device.prepare()
        var first: [EMGSample] = []
        for try await sample in try await device.start() { first.append(sample) }
        var second: [EMGSample] = []
        for try await sample in try await device.start() { second.append(sample) }
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.count, 8)
        XCTAssertEqual(first.last!.timestamp, 0.175, accuracy: 0.000001)
        XCTAssertTrue(first.allSatisfy { $0.value.isFinite })
        XCTAssertEqual(device.origin, .demo)
    }

    func testRealDeviceIsExplicitlyUnavailable() async {
        let device = UnavailableBLEMeasurementDevice()
        do { try await device.prepare(); XCTFail("No hardware adapter exists") }
        catch { XCTAssertEqual(error as? MeasurementDeviceError, .unavailable) }
    }
}

private final class MemoryRepository: AppRepository {
    var snapshot: AppSnapshot?
    var failSaving = false
    var failLoading = false
    var saveCount = 0
    init(snapshot: AppSnapshot?) { self.snapshot = snapshot }
    func load() throws -> AppSnapshot? {
        if failLoading { throw CocoaError(.fileReadCorruptFile) }
        return snapshot
    }
    func save(_ snapshot: AppSnapshot) throws {
        if failSaving { throw CocoaError(.fileWriteNoPermission) }
        self.snapshot = snapshot
        saveCount += 1
    }
}
