import Foundation

public enum FeaturedMetric: String, Codable, CaseIterable, Identifiable, Sendable {
    case benchPress, armSpan, consistency
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .benchPress: return "卧推力量"
        case .armSpan: return "臂展比例"
        case .consistency: return "记录习惯"
        }
    }
}

public enum ProfileVisibility: String, Codable, CaseIterable, Identifiable, Sendable {
    case friends, everyone, onlyMe
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .friends: return "关注的人"
        case .everyone: return "所有人"
        case .onlyMe: return "仅自己"
        }
    }
}

public enum MeasurementKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case body, strength, emg
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .body: return "身体特征"
        case .strength: return "力量"
        case .emg: return "肌电"
        }
    }
    public var systemImage: String {
        switch self {
        case .body: return "figure.stand"
        case .strength: return "dumbbell.fill"
        case .emg: return "waveform.path.ecg"
        }
    }
}

public enum DataOrigin: String, Codable, CaseIterable, Sendable {
    case demo, manual, device
    public var title: String {
        switch self {
        case .demo: return "演示数据"
        case .manual: return "手动记录"
        case .device: return "设备测量"
        }
    }
}

public struct UserProfile: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var handle: String
    public var bio: String
    public var heightCM: Double
    public var weightKG: Double
    public var armSpanCM: Double
    public var waistCM: Double
    public var featuredMetric: FeaturedMetric
    public var visibility: ProfileVisibility

    public init(id: String, name: String, handle: String, bio: String, heightCM: Double, weightKG: Double, armSpanCM: Double, waistCM: Double, featuredMetric: FeaturedMetric, visibility: ProfileVisibility) {
        self.id = id; self.name = name; self.handle = handle; self.bio = bio
        self.heightCM = heightCM; self.weightKG = weightKG; self.armSpanCM = armSpanCM; self.waistCM = waistCM
        self.featuredMetric = featuredMetric; self.visibility = visibility
    }
}

public struct MeasurementRecord: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var date: Date
    public var kind: MeasurementKind
    public var title: String
    public var value: Double
    public var unit: String
    public var secondaryValue: Double?
    public var origin: DataOrigin
    public var note: String

    public init(id: UUID = UUID(), date: Date = Date(), kind: MeasurementKind, title: String, value: Double, unit: String, secondaryValue: Double? = nil, origin: DataOrigin, note: String = "") {
        self.id = id; self.date = date; self.kind = kind; self.title = title; self.value = value
        self.unit = unit; self.secondaryValue = secondaryValue; self.origin = origin; self.note = note
    }
}

public struct PostComment: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var authorName: String
    public var text: String
    public var date: Date
    public init(id: UUID = UUID(), authorName: String, text: String, date: Date = Date()) {
        self.id = id; self.authorName = authorName; self.text = text; self.date = date
    }
}

public struct FeedPost: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var authorID: String
    public var authorName: String
    public var handle: String
    public var initials: String
    public var caption: String
    public var metricTitle: String
    public var metricValue: String
    public var metricUnit: String
    public var tag: String
    public var date: Date
    public var likes: Int
    public var isLiked: Bool
    public var comments: [PostComment]
    public var origin: DataOrigin

    public init(id: UUID = UUID(), authorID: String, authorName: String, handle: String, initials: String, caption: String, metricTitle: String, metricValue: String, metricUnit: String, tag: String, date: Date = Date(), likes: Int = 0, isLiked: Bool = false, comments: [PostComment] = [], origin: DataOrigin) {
        self.id = id; self.authorID = authorID; self.authorName = authorName; self.handle = handle; self.initials = initials
        self.caption = caption; self.metricTitle = metricTitle; self.metricValue = metricValue; self.metricUnit = metricUnit
        self.tag = tag; self.date = date; self.likes = likes; self.isLiked = isLiked; self.comments = comments; self.origin = origin
    }
}

public struct Person: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var handle: String
    public var initials: String
    public var bio: String
    public var isFollowing: Bool
    public init(id: String, name: String, handle: String, initials: String, bio: String, isFollowing: Bool) {
        self.id = id; self.name = name; self.handle = handle; self.initials = initials; self.bio = bio; self.isFollowing = isFollowing
    }
}

public struct RankEntry: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var initials: String
    public var value: Double
    public var isCurrentUser: Bool
    public init(id: String, name: String, initials: String, value: Double, isCurrentUser: Bool) {
        self.id = id; self.name = name; self.initials = initials; self.value = value; self.isCurrentUser = isCurrentUser
    }
}

public struct AppSnapshot: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var profile: UserProfile
    public var records: [MeasurementRecord]
    public var posts: [FeedPost]
    public var people: [Person]
    public init(schemaVersion: Int = 1, profile: UserProfile, records: [MeasurementRecord], posts: [FeedPost], people: [Person]) {
        self.schemaVersion = schemaVersion; self.profile = profile; self.records = records; self.posts = posts; self.people = people
    }
}
