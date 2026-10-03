import Foundation
import Observation

@MainActor @Observable
public final class AppStore {
    public private(set) var profile: UserProfile
    public private(set) var records: [MeasurementRecord]
    public private(set) var posts: [FeedPost]
    public private(set) var people: [Person]
    public private(set) var rankingMeasurements: [RankingMeasurement]
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
        rankingMeasurements = initial.rankingMeasurements ?? (useDemoData ? RankingSampleData.measurements(for: initial.people) : [])
        persistenceError = initialError
    }

    public var latestBody: MeasurementRecord? { latest(.body) }
    public var latestStrength: MeasurementRecord? { latest(.strength) }
    public var latestEMG: MeasurementRecord? { latest(.emg) }

    public func latestRankingMeasurement(for metric: RankingMetric) -> RankingMeasurement? {
        latestRankingMeasurement(for: metric, personID: profile.id)
    }

    /// Same metric and explicit manual protocol; descending size is not a talent score.
    /// The latest matching record is validated after selection, so corruption cannot revive an older result.
    public func rankingEntries(for metric: RankingMetric, followingOnly: Bool = false) -> [EvidenceRankEntry] {
        var entries: [EvidenceRankEntry] = []
        var ids: Set<String> = []
        let candidates = people.filter { $0.id != profile.id && (!followingOnly || $0.isFollowing) }
            + [Person(id: profile.id, name: profile.name, handle: profile.handle, initials: String(profile.name.prefix(1)), bio: profile.bio, isFollowing: true)]
        for person in candidates where ids.insert(person.id).inserted {
            guard let measurement = latestRankingMeasurement(for: metric, personID: person.id),
                  let value = try? measurement.calculatedValue() else { continue }
            entries.append(EvidenceRankEntry(id: person.id, name: person.name, initials: person.initials, value: value, position: 0, isCurrentUser: person.id == profile.id, measurement: measurement))
        }
        // Use the very same formatter as the UI, including its rounding at decimal boundaries.
        func displayedValue(_ entry: EvidenceRankEntry) -> Double { Double(metric.formattedValue(entry.value)) ?? entry.value }
        entries.sort {
            let lhs = displayedValue($0), rhs = displayedValue($1)
            if lhs != rhs { return lhs > rhs }
            if $0.measurement.date != $1.measurement.date { return $0.measurement.date < $1.measurement.date }
            if $0.id != $1.id { return $0.id < $1.id }
            return $0.measurement.id.uuidString < $1.measurement.id.uuidString
        }
        for index in entries.indices {
            entries[index].position = index > 0 && displayedValue(entries[index]) == displayedValue(entries[index - 1])
                ? entries[index - 1].position : index + 1
        }
        return entries
    }

    public func saveRankingMeasurement(_ record: RankingMeasurement) {
        do {
            guard record.personID == profile.id else { throw RankingValidationError.notCurrentUser }
            if let existing = rankingMeasurements.first(where: { $0.id == record.id }),
               existing.personID != record.personID || existing.metric != record.metric {
                throw RankingValidationError.recordIdentityMismatch
            }
            _ = try record.calculatedValue()
        } catch { persistenceError = "测量未保存：\(error.localizedDescription)"; return }
        transaction { snapshot in
            var measurements = snapshot.rankingMeasurements ?? []
            measurements.removeAll { $0.id == record.id }
            measurements.insert(record, at: 0)
            snapshot.rankingMeasurements = measurements
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

    private var snapshot: AppSnapshot { AppSnapshot(profile: profile, records: records, posts: posts, people: people, rankingMeasurements: rankingMeasurements) }

    private func latest(_ kind: MeasurementKind) -> MeasurementRecord? {
        records.filter { $0.kind == kind }.max { $0.date < $1.date }
    }

    private func latestRankingMeasurement(for metric: RankingMetric, personID: String) -> RankingMeasurement? {
        let matching = rankingMeasurements.filter { $0.personID == personID && $0.metric == metric && $0.protocolID == metric.protocolID }
        // An invalid date cannot establish which measurement is newest; do not select an older result.
        if let invalid = matching.first(where: { !$0.date.timeIntervalSince1970.isFinite }) { return invalid }
        return matching.max {
            if $0.date != $1.date { return $0.date < $1.date }
            return $0.id.uuidString < $1.id.uuidString
        }
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
            rankingMeasurements = candidate.rankingMeasurements ?? []
            loadingFailed = false
            persistenceError = nil
        } catch { persistenceError = "本地保存失败：\(error.localizedDescription) 更改未应用。" }
    }

    private static func number(_ value: Double) -> String {
        value.rounded() == value ? String(format: "%.0f", value) : String(format: "%.1f", value)
    }
}
