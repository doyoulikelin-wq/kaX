import Foundation

public protocol AppRepository {
    func load() throws -> AppSnapshot?
    func save(_ snapshot: AppSnapshot) throws
}

public enum RepositoryError: LocalizedError {
    case unsupportedVersion(Int)
    public var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version): return "无法读取版本 \(version) 的本地数据。原文件已保留。"
        }
    }
}

public struct LocalAppRepository: AppRepository {
    public let url: URL

    public init(url: URL? = nil) {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.url = url ?? support.appendingPathComponent("kaX", isDirectory: true).appendingPathComponent("snapshot.json")
    }

    public func load() throws -> AppSnapshot? {
        let data: Data
        do { data = try Data(contentsOf: url) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile { return nil }
        let snapshot = try JSONDecoder().decode(AppSnapshot.self, from: data)
        guard snapshot.schemaVersion == 1 else { throw RepositoryError.unsupportedVersion(snapshot.schemaVersion) }
        return snapshot
    }

    public func save(_ snapshot: AppSnapshot) throws {
        let data = try Self.encode(snapshot)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        // Foundation writes a temporary sibling and replaces the destination on success.
        try data.write(to: url, options: .atomic)
    }

    public static func encode(_ snapshot: AppSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(snapshot)
    }
}
