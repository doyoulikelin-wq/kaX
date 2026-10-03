import Foundation

/// Synthetic offline examples, not observations from a study or a population reference.
/// Values are raw dimensions; ranking values are always calculated by RankingMetric.
public enum RankingSampleData {
    private static let dimensions: [(String, [String: Double])] = [
        ("kax_me", ["heightCM": 178, "armSpanCM": 184, "sittingHeightCM": 92, "shoulderWidthCM": 46, "waistWidthCM": 28, "hipWidthCM": 35, "waistGirthCM": 78, "hipGirthCM": 96, "handWidthCM": 8.5, "handLengthCM": 19, "footWidthCM": 10, "footLengthCM": 26]),
        ("lin", ["heightCM": 182, "armSpanCM": 186, "sittingHeightCM": 94, "shoulderWidthCM": 49, "waistWidthCM": 30, "hipWidthCM": 36, "waistGirthCM": 84, "hipGirthCM": 101, "handWidthCM": 9, "handLengthCM": 20, "footWidthCM": 10.5, "footLengthCM": 27.5]),
        ("yu", ["heightCM": 172, "armSpanCM": 182, "sittingHeightCM": 88, "shoulderWidthCM": 44, "waistWidthCM": 27, "hipWidthCM": 33, "waistGirthCM": 75, "hipGirthCM": 93, "handWidthCM": 8, "handLengthCM": 18.5, "footWidthCM": 9.5, "footLengthCM": 25]),
        ("an", ["heightCM": 168, "armSpanCM": 170, "sittingHeightCM": 89, "shoulderWidthCM": 42, "waistWidthCM": 26, "hipWidthCM": 34, "waistGirthCM": 72, "hipGirthCM": 95, "handWidthCM": 7.8, "handLengthCM": 18, "footWidthCM": 9.1, "footLengthCM": 24]),
        ("chen", ["heightCM": 180, "armSpanCM": 183, "sittingHeightCM": 93, "shoulderWidthCM": 47, "waistWidthCM": 31, "hipWidthCM": 37, "waistGirthCM": 86, "hipGirthCM": 103, "handWidthCM": 8.8, "handLengthCM": 19.5, "footWidthCM": 10.2, "footLengthCM": 27]),
        ("xia", ["heightCM": 162, "armSpanCM": 163, "sittingHeightCM": 85, "shoulderWidthCM": 39, "waistWidthCM": 25, "hipWidthCM": 35, "waistGirthCM": 69, "hipGirthCM": 96, "handWidthCM": 7.2, "handLengthCM": 17, "footWidthCM": 8.8, "footLengthCM": 23])
    ]

    public static let measurements: [RankingMeasurement] = dimensions.enumerated().flatMap { personIndex, person in
        RankingMetric.allCases.enumerated().map { metricIndex, metric in
            let values = Dictionary(uniqueKeysWithValues: metric.inputFields.map { ($0.id, person.1[$0.id]!) })
            let number = 500 + personIndex * 20 + metricIndex
            return RankingMeasurement(id: UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", number))!, personID: person.0, metric: metric, values: values, date: SampleData.referenceDate.addingTimeInterval(-3_600), origin: .demo)
        }
    }

    /// Legacy snapshots may display known sample peers without inventing a new user measurement.
    public static func measurements(for people: [Person]) -> [RankingMeasurement] {
        let ids = Set(people.map(\.id))
        return measurements.filter { $0.personID != "kax_me" && ids.contains($0.personID) }
    }
}
