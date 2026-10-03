import Foundation

public struct EMGSample: Equatable, Sendable {
    /// Seconds since the start of this acquisition, independent of BLE arrival time.
    public let timestamp: TimeInterval
    /// Demonstration voltage in mV. A hardware adapter must specify its own calibrated unit.
    public let value: Double
    public init(timestamp: TimeInterval, value: Double) { self.timestamp = timestamp; self.value = value }
}

public protocol MeasurementDevice: Sendable {
    var name: String { get }
    var origin: DataOrigin { get }
    func prepare() async throws
    func start() async throws -> AsyncThrowingStream<EMGSample, Error>
    func stop() async
}

public enum MeasurementDeviceError: LocalizedError, Equatable {
    case unavailable, notPrepared, invalidConfiguration
    public var errorDescription: String? {
        switch self {
        case .unavailable: return "尚未接入实体肌电设备。可以先体验演示波形。"
        case .notPrepared: return "请先准备测量设备。"
        case .invalidConfiguration: return "演示采样参数无效。"
        }
    }
}

/// Deterministic preview only; it never discovers or impersonates a Bluetooth peripheral.
public actor DemoMeasurementDevice: MeasurementDevice {
    public nonisolated let name = "肌电演示"
    public nonisolated let origin: DataOrigin = .demo
    private let sampleCount: Int
    private let sampleInterval: TimeInterval
    private let realtime: Bool
    private var prepared = false
    private var acquisition: Task<Void, Never>?

    public init(sampleCount: Int = 240, sampleInterval: TimeInterval = 0.025, realtime: Bool = true) {
        self.sampleCount = sampleCount; self.sampleInterval = sampleInterval; self.realtime = realtime
    }

    public func prepare() async throws {
        guard (1...10_000).contains(sampleCount), sampleInterval.isFinite, (0.001...1).contains(sampleInterval) else {
            throw MeasurementDeviceError.invalidConfiguration
        }
        prepared = true
    }

    public func start() async throws -> AsyncThrowingStream<EMGSample, Error> {
        guard prepared else { throw MeasurementDeviceError.notPrepared }
        acquisition?.cancel()
        let count = sampleCount
        let interval = sampleInterval
        let paced = realtime
        let (stream, continuation) = AsyncThrowingStream<EMGSample, Error>.makeStream()
        let task = Task<Void, Never> {
            for index in 0..<count {
                guard !Task.isCancelled else { continuation.finish(); return }
                let time = Double(index) * interval
                continuation.yield(EMGSample(timestamp: time, value: Self.demoValue(at: time)))
                if paced {
                    do { try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000)) }
                    catch { continuation.finish(); return }
                }
            }
            continuation.finish()
        }
        continuation.onTermination = { @Sendable _ in task.cancel() }
        acquisition = task
        return stream
    }

    public func stop() async {
        acquisition?.cancel()
        acquisition = nil
    }

    public nonisolated static func demoValue(at time: TimeInterval) -> Double {
        let envelope = 0.18 + 0.25 * pow(sin(.pi * time / 1.8), 2)
        let carrier = 0.65 * sin(2 * .pi * 7 * time) + 0.35 * sin(2 * .pi * 13 * time)
        return envelope * carrier
    }
}

/// Placeholder until the actual manufacturer's service contract and calibration are known.
/// No service or characteristic UUID is invented here.
public struct UnavailableBLEMeasurementDevice: MeasurementDevice {
    public let name = "实体肌电设备尚未接入"
    public let origin: DataOrigin = .device
    public init() {}
    public func prepare() async throws { throw MeasurementDeviceError.unavailable }
    public func start() async throws -> AsyncThrowingStream<EMGSample, Error> { throw MeasurementDeviceError.unavailable }
    public func stop() async {}
}
