import Foundation
import Observation

@MainActor @Observable
public final class AppStore {
    public private(set) var profile: UserProfile
    public private(set) var records: [MeasurementRecord]
    public private(set) var posts: [FeedPost]
    public private(set) var people: [Person]
    public private(set) var persistenceError: String?

    @ObservationIgnored private let repository: any AppRepository
    @ObservationIgnored private var loadingFailed = false

    public init(repository: any AppRepository = LocalAppRepository(), useDemoData: Bool = true) {
        self.repository = repository
        let fallback = useDemoData ? SampleData.snapshot : SampleData.emptySnapshot
        var initial = fallback
        var initialError: String?
        do {
            if let loaded = try repository.load() {
                initial = loaded
            } else {
                do { try repository.save(initial) }
                catch { initialError = "本地保存失败：\(error.localizedDescription)" }
            }
        } catch {
            loadingFailed = true
            initialError = "本地读取失败：\(error.localizedDescription) 原文件已保留，暂不能覆盖保存。"
        }
        profile = initial.profile; records = initial.records; posts = initial.posts; people = initial.people
        persistenceError = initialError
    }

    public var latestBody: MeasurementRecord? { latest(.body) }
    public var latestStrength: MeasurementRecord? { latest(.strength) }
    public var latestEMG: MeasurementRecord? { latest(.emg) }

    /// Offline sample comparison of bench-press estimated 1RM / body weight.
    /// A profile's featured card metric does not change this leaderboard.
    public var leaderboard: [RankEntry] {
        var entries = people.compactMap { person -> RankEntry? in
            guard let value = SampleData.benchPressRatios[person.id] else { return nil }
            return RankEntry(id: person.id, name: person.name, initials: person.initials, value: value, isCurrentUser: false)
        }
        let hasMeasuredBody = latestBody.map { $0.origin != .demo } ?? false
        if let record = latestStrength, record.origin == .demo || hasMeasuredBody,
           let oneRepMax = estimatedMaximum(for: record),
           let ratio = try? ScoreCalculator.relativeStrength(oneRepMax: oneRepMax, bodyWeight: profile.weightKG) {
            entries.append(RankEntry(id: profile.id, name: profile.name, initials: String(profile.name.prefix(1)), value: ratio, isCurrentUser: true))
        }
        return entries.sorted {
            if $0.value != $1.value { return $0.value > $1.value }
            if $0.isCurrentUser != $1.isCurrentUser { return $0.isCurrentUser }
            return $0.id < $1.id
        }
    }

    public func saveProfile(_ newProfile: UserProfile) {
        guard validProfile(newProfile) else { persistenceError = "个人资料含有无效数值，未保存。"; return }
        transaction { $0.profile = newProfile }
    }

    public func addRecord(_ record: MeasurementRecord) {
        guard validRecord(record) else { persistenceError = "记录含有无效数值，未保存。"; return }
        transaction { snapshot in
            snapshot.records.removeAll { $0.id == record.id }
            snapshot.records.insert(record, at: 0)
        }
    }

    public func saveBodyMeasurement(profile newProfile: UserProfile, record: MeasurementRecord) {
        guard validProfile(newProfile, allowsUnchangedEmpty: false), record.kind == .body, validRecord(record) else {
            persistenceError = "身体测量含有无效数值，未保存。"; return
        }
        transaction { snapshot in
            snapshot.profile = newProfile
            snapshot.records.removeAll { $0.id == record.id }
            snapshot.records.insert(record, at: 0)
        }
    }

    public func recordBody(profile: UserProfile, record: MeasurementRecord) {
        saveBodyMeasurement(profile: profile, record: record)
    }

    public func toggleLike(postID: UUID) {
        guard posts.contains(where: { $0.id == postID }) else { return }
        transaction { snapshot in
            guard let index = snapshot.posts.firstIndex(where: { $0.id == postID }) else { return }
            let liked = snapshot.posts[index].isLiked
            snapshot.posts[index].isLiked.toggle()
            let (total, overflow) = snapshot.posts[index].likes.addingReportingOverflow(liked ? -1 : 1)
            snapshot.posts[index].likes = overflow ? (liked ? 0 : Int.max) : max(0, total)
        }
    }

    public func toggleFollow(personID: String) {
        guard people.contains(where: { $0.id == personID }) else { return }
        transaction { snapshot in
            guard let index = snapshot.people.firstIndex(where: { $0.id == personID }) else { return }
            snapshot.people[index].isFollowing.toggle()
        }
    }

    public func addComment(postID: UUID, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, posts.contains(where: { $0.id == postID }) else { return }
        transaction { snapshot in
            guard let index = snapshot.posts.firstIndex(where: { $0.id == postID }) else { return }
            snapshot.posts[index].comments.append(PostComment(authorName: snapshot.profile.name, text: trimmed))
        }
    }

    /// Adds a local post. This app has no remote publishing service.
    public func publish(caption: String, recordID: UUID?) {
        let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        let record = recordID.flatMap { id in records.first(where: { $0.id == id }) }
        guard recordID == nil || record != nil else { persistenceError = "找不到分享的记录，未发布。"; return }
        guard !trimmed.isEmpty || record != nil else { return }
        let metricUnit = record.map { measurement in
            if measurement.kind == .strength, let repetitions = measurement.secondaryValue {
                return "\(measurement.unit) × \(Self.number(repetitions))"
            }
            return measurement.unit
        } ?? ""
        transaction { snapshot in
            let post = FeedPost(authorID: snapshot.profile.id, authorName: snapshot.profile.name, handle: snapshot.profile.handle, initials: String(snapshot.profile.name.prefix(1)), caption: trimmed, metricTitle: record?.title ?? "我的近况", metricValue: record.map { Self.number($0.value) } ?? "", metricUnit: metricUnit, tag: record?.kind.title ?? "日常记录", origin: record?.origin ?? .manual)
            snapshot.posts.insert(post, at: 0)
        }
    }

    public func resetDemo() {
        // Explicit reset is the only action permitted to replace an unreadable snapshot.
        commit(SampleData.snapshot, permitsRecovery: true)
    }

    public func exportData() -> Data? {
        guard !loadingFailed else {
            persistenceError = "本地数据未能读取，原文件已保留。请先恢复数据或显式重置演示，暂不能导出演示替代数据。"
            return nil
        }
        do { return try LocalAppRepository.encode(snapshot) }
        catch { persistenceError = "导出失败：\(error.localizedDescription)"; return nil }
    }

    private var snapshot: AppSnapshot { AppSnapshot(profile: profile, records: records, posts: posts, people: people) }

    private func latest(_ kind: MeasurementKind) -> MeasurementRecord? {
        records.filter { $0.kind == kind }.max { $0.date < $1.date }
    }

    private func estimatedMaximum(for record: MeasurementRecord) -> Double? {
        guard let repetitions = record.secondaryValue else { return record.value }
        guard repetitions.isFinite, (1...30).contains(repetitions), repetitions.rounded() == repetitions else { return nil }
        return try? ScoreCalculator.estimatedOneRepMax(weight: record.value, repetitions: Int(repetitions))
    }

    private func validProfile(_ candidate: UserProfile, allowsUnchangedEmpty: Bool = true) -> Bool {
        guard candidate.id == profile.id,
              !candidate.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              candidate.name.count <= 24, candidate.bio.count <= 120 else { return false }
        let measurements: [(Double, Double, ClosedRange<Double>)] = [
            (candidate.heightCM, profile.heightCM, 50...260),
            (candidate.weightKG, profile.weightKG, 20...500),
            (candidate.armSpanCM, profile.armSpanCM, 50...300),
            (candidate.waistCM, profile.waistCM, 30...300)
        ]
        // Zero means "not entered" only when that field was already empty.
        return measurements.allSatisfy { value, previous, range in
            value.isFinite && (range.contains(value) || (allowsUnchangedEmpty && value == 0 && previous == 0))
        }
    }

    private func validRecord(_ record: MeasurementRecord) -> Bool {
        guard record.value.isFinite, record.value >= 0, record.date.timeIntervalSince1970.isFinite else { return false }
        if record.kind != .emg && record.value == 0 { return false }
        if record.kind == .strength && !(1...1000).contains(record.value) { return false }
        if let secondary = record.secondaryValue {
            guard secondary.isFinite else { return false }
            if record.kind == .strength && (!(1...30).contains(secondary) || secondary.rounded() != secondary) { return false }
        }
        return true
    }

    private func transaction(_ mutation: (inout AppSnapshot) -> Void) {
        var candidate = snapshot
        mutation(&candidate)
        commit(candidate)
    }

    private func commit(_ candidate: AppSnapshot, permitsRecovery: Bool = false) {
        guard !loadingFailed || permitsRecovery else {
            persistenceError = "本地数据未能读取，原文件已保留。请先恢复数据或显式重置演示，暂不能覆盖保存。"
            return
        }
        do {
            // Save before applying, so an I/O failure cannot leave the visible state ahead of disk.
            try repository.save(candidate)
            profile = candidate.profile; records = candidate.records; posts = candidate.posts; people = candidate.people
            loadingFailed = false
            persistenceError = nil
        } catch { persistenceError = "本地保存失败：\(error.localizedDescription) 更改未应用。" }
    }

    private static func number(_ value: Double) -> String {
        value.rounded() == value ? String(format: "%.0f", value) : String(format: "%.1f", value)
    }
}
