import Foundation

/// Immutable fixtures for an offline preview. Every sample record and post is marked demo.
public enum SampleData {
    // Anchor once per process so preview events always precede new user records.
    public static let referenceDate = Date()
    public static let profile = UserProfile(id: "kax_me", name: "我", handle: "@kax_me", bio: "认识自己的特点，也看见每一次进步。", heightCM: 178, weightKG: 72, armSpanCM: 184, waistCM: 78, featuredMetric: .armSpan, visibility: .friends)

    public static let people: [Person] = [
        Person(id: "lin", name: "林野", handle: "@lin_moves", initials: "林", bio: "记录力量，收集进步。", isFollowing: true),
        Person(id: "yu", name: "余舟", handle: "@yuzhou", initials: "余", bio: "长臂选手，慢慢变强。", isFollowing: true),
        Person(id: "an", name: "安可", handle: "@anko", initials: "安", bio: "每周三次，保持自己的节奏。", isFollowing: true),
        Person(id: "chen", name: "陈墨", handle: "@chen_m", initials: "陈", bio: "今天也留下一个记录。", isFollowing: false),
        Person(id: "xia", name: "夏夏", handle: "@xiaxia", initials: "夏", bio: "寻找一起坚持的朋友。", isFollowing: false)
    ]

    public static let records: [MeasurementRecord] = [
        MeasurementRecord(id: uuid(1), date: referenceDate.addingTimeInterval(-3_600), kind: .body, title: "臂展", value: 184, unit: "cm", secondaryValue: 178, origin: .demo, note: "演示记录 · 臂展 / 身高 = 1.034"),
        MeasurementRecord(id: uuid(2), date: referenceDate.addingTimeInterval(-86_400), kind: .strength, title: "卧推", value: 70, unit: "kg", secondaryValue: 5, origin: .demo, note: "演示记录 · 70 kg × 5 次；估算 1RM 81.7 kg"),
        MeasurementRecord(id: uuid(3), date: referenceDate.addingTimeInterval(-172_800), kind: .emg, title: "肌电活动", value: 0.42, unit: "mV", origin: .demo, note: "确定性演示波形；非真实设备测量"),
        MeasurementRecord(id: uuid(4), date: referenceDate.addingTimeInterval(-604_800), kind: .strength, title: "卧推", value: 65, unit: "kg", secondaryValue: 5, origin: .demo, note: "演示记录 · 65 kg × 5 次"),
        MeasurementRecord(id: uuid(5), date: referenceDate.addingTimeInterval(-1_209_600), kind: .body, title: "臂展", value: 184, unit: "cm", secondaryValue: 178, origin: .demo, note: "演示记录")
    ]

    public static let posts: [FeedPost] = [
        FeedPost(id: uuid(101), authorID: "lin", authorName: "林野", handle: "@lin_moves", initials: "林", caption: "第一次把卧推记录到自己的卡片上。下一站，保持节奏。", metricTitle: "卧推估算 1RM", metricValue: "105", metricUnit: "kg", tag: "力量进步", date: referenceDate.addingTimeInterval(-1_800), likes: 24, comments: [PostComment(id: uuid(201), authorName: "安可", text: "这个进步很稳。", date: referenceDate.addingTimeInterval(-900))], origin: .demo),
        FeedPost(id: uuid(102), authorID: "yu", authorName: "余舟", handle: "@yuzhou", initials: "余", caption: "原来我的臂展比身高长这么多。给自己一个新标签。", metricTitle: "臂展 / 身高", metricValue: "1.06", metricUnit: "倍", tag: "高触达型", date: referenceDate.addingTimeInterval(-7_200), likes: 18, origin: .demo),
        FeedPost(id: uuid(103), authorID: "an", authorName: "安可", handle: "@anko", initials: "安", caption: "没有很大的数字，不过这个月留下了 12 次记录。", metricTitle: "本月记录", metricValue: "12", metricUnit: "次", tag: "持续记录", date: referenceDate.addingTimeInterval(-14_400), likes: 32, origin: .demo),
        FeedPost(id: uuid(104), authorID: "chen", authorName: "陈墨", handle: "@chen_m", initials: "陈", caption: "今天体验了肌电采集流程，保存了第一条演示记录。", metricTitle: "肌电演示", metricValue: "0.38", metricUnit: "mV", tag: "数据探索", date: referenceDate.addingTimeInterval(-43_200), likes: 9, origin: .demo),
        FeedPost(id: uuid(105), authorID: "xia", authorName: "夏夏", handle: "@xiaxia", initials: "夏", caption: "自己的卡片，慢慢更新。有人一起记录吗？", metricTitle: "卧推估算 1RM", metricValue: "48", metricUnit: "kg", tag: "力量起点", date: referenceDate.addingTimeInterval(-86_400), likes: 16, origin: .demo)
    ]

    public static let snapshot = AppSnapshot(profile: profile, records: records, posts: posts, people: people)
    public static let emptySnapshot = AppSnapshot(profile: UserProfile(id: "kax_me", name: "我", handle: "@kax_me", bio: "", heightCM: 0, weightKG: 0, armSpanCM: 0, waistCM: 0, featuredMetric: .benchPress, visibility: .friends), records: [], posts: [], people: [])
    public static let benchPressRatios: [String: Double] = ["lin": 1.40, "yu": 1.21, "an": 1.02, "chen": 0.96, "xia": 0.80]

    private static func uuid(_ number: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", number))!
    }
}
