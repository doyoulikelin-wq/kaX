import Foundation

public enum ScoreError: LocalizedError, Equatable {
    case invalidWeight, invalidRepetitions, invalidBodyWeight, invalidDimensions
    public var errorDescription: String? {
        switch self {
        case .invalidWeight: return "重量需要是大于 0 的有限数值。"
        case .invalidRepetitions: return "重复次数需要是 1 至 30 次。"
        case .invalidBodyWeight: return "体重需要是大于 0 的有限数值。"
        case .invalidDimensions: return "身高和臂展需要是大于 0 的有限数值。"
        }
    }
}

public enum ScoreCalculator {
    /// Legacy Epley estimate; not used by the current static dimension rankings.
    /// A completed single repetition is returned without extrapolation.
    public static func estimatedOneRepMax(weight: Double, repetitions: Int) throws -> Double {
        guard weight.isFinite, weight > 0 else { throw ScoreError.invalidWeight }
        guard (1...30).contains(repetitions) else { throw ScoreError.invalidRepetitions }
        let result = repetitions == 1 ? weight : weight * (1 + Double(repetitions) / 30)
        guard result.isFinite else { throw ScoreError.invalidWeight }
        return result
    }

    public static func relativeStrength(oneRepMax: Double, bodyWeight: Double) throws -> Double {
        guard oneRepMax.isFinite, oneRepMax > 0 else { throw ScoreError.invalidWeight }
        guard bodyWeight.isFinite, bodyWeight > 0 else { throw ScoreError.invalidBodyWeight }
        let result = oneRepMax / bodyWeight
        guard result.isFinite else { throw ScoreError.invalidBodyWeight }
        return result
    }

    public static func relativeStrength(weight: Double, repetitions: Int, bodyWeight: Double) throws -> Double {
        try relativeStrength(oneRepMax: estimatedOneRepMax(weight: weight, repetitions: repetitions), bodyWeight: bodyWeight)
    }

    public static func armSpanRatio(armSpanCM: Double, heightCM: Double) throws -> Double {
        guard armSpanCM.isFinite, heightCM.isFinite, armSpanCM > 0, heightCM > 0 else { throw ScoreError.invalidDimensions }
        let result = armSpanCM / heightCM
        guard result.isFinite else { throw ScoreError.invalidDimensions }
        return result
    }

    public static func armSpanRatio(armSpan: Double, height: Double) throws -> Double {
        try armSpanRatio(armSpanCM: armSpan, heightCM: height)
    }
}
