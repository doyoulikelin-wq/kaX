import Foundation

public enum StaticFeatureID: String, CaseIterable, Codable, Identifiable, Sendable {
    case sm01 = "SM01", sm02 = "SM02", sm03 = "SM03", sm04 = "SM04", sm05 = "SM05"
    case sm07 = "SM07", sm08 = "SM08", sm09 = "SM09", sm10 = "SM10", sm11 = "SM11"
    case sm12 = "SM12", sm13 = "SM13", sm16 = "SM16"
    case sr01 = "SR01", sr02 = "SR02", sr03 = "SR03", sr04 = "SR04", sr05 = "SR05", sr06 = "SR06"
    case h01 = "H01", h02 = "H02", h03 = "H03", q01 = "Q01", q02 = "Q02"
    public var id: String { rawValue }
    public var protocolID: String { "kax.static.catalog.\(rawValue.lowercased()).v1" }
}

public enum StaticInputKind: String, Codable, Sendable { case number, series, text, date }
public enum StaticFeatureAvailability: String, Codable, Sendable { case available, requiresReferenceLibrary }

public struct StaticInputField: Identifiable, Codable, Equatable, Sendable {
    public var key: String
    public var title: String
    public var unit: String
    public var kind: StaticInputKind
    public var optional: Bool
    public var range: ClosedRange<Double>?
    public var options: [String]
    public var isInteger: Bool
    public var id: String { key }
    public var required: Bool { !optional }
    public var allowedRange: ClosedRange<Double>? { range }
    public init(key: String, title: String, unit: String = "", kind: StaticInputKind = .number, optional: Bool = false, range: ClosedRange<Double>? = nil, options: [String] = [], isInteger: Bool = false) {
        self.key = key; self.title = title; self.unit = unit; self.kind = kind; self.optional = optional
        self.range = range; self.options = options; self.isInteger = isInteger
    }
}

public struct StaticSourceReference: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var url: String?
    public var evidence: String
    public var limitations: String
    public var access: String
    public var reportSection: String { "静态功能公式表来源索引 \(id)" }
    public init(id: String, title: String, url: String?, evidence: String = "", limitations: String = "", access: String = "") {
        self.id = id; self.title = title; self.url = url; self.evidence = evidence; self.limitations = limitations; self.access = access
    }
}

public struct StaticFeatureMetadata: Identifiable, Equatable, Sendable {
    public let id: StaticFeatureID
    public let title: String
    public let category: String
    public let group: String
    public let data: String
    public let formula: String
    public let measurementGuide: String
    public let interpretation: String
    public let limitations: String
    public let evidence: String
    public let validation: String
    public let talentInference: String
    public let route: String
    public let mode: String
    public let type: String
    public let formulaType: String
    public let sourceIDs: [String]
    public let sourceReferences: [StaticSourceReference]
    public let inputFields: [StaticInputField]
    public let availability: StaticFeatureAvailability
    public var protocolID: String { id.protocolID }
}

public struct StaticTargetMetric: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var feature: StaticFeatureID
    public var metricKey: String { id }
    public init(id: String, title: String, feature: StaticFeatureID) { self.id = id; self.title = title; self.feature = feature }
}

public struct StaticTargetComponent: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var metricKey: String
    public var observed: Double
    public var lowerBound: Double
    public var upperBound: Double
    public var scale: Double
    public var weight: Double
    public init(id: String = UUID().uuidString, title: String, metricKey: String, observed: Double, lowerBound: Double, upperBound: Double, scale: Double, weight: Double) {
        self.id = id; self.title = title; self.metricKey = metricKey; self.observed = observed
        self.lowerBound = lowerBound; self.upperBound = upperBound; self.scale = scale; self.weight = weight
    }
}

public struct StaticMeasurementInput: Codable, Equatable, Sendable {
    public var values: [String: Double]
    public var series: [String: [Double]]
    /// Extensible acquisition context, such as side, pointSource, modelRevision and imageID.
    public var text: [String: String]
    public var dates: [String: Date]
    public var targets: [StaticTargetComponent]
    public var metadata: [String: String]
    public init(values: [String: Double] = [:], series: [String: [Double]] = [:], text: [String: String] = [:], dates: [String: Date] = [:], targets: [StaticTargetComponent] = [], metadata: [String: String] = [:]) {
        self.values = values; self.series = series; self.text = text; self.dates = dates; self.targets = targets
        self.metadata = metadata
    }
}

public struct StaticResultValue: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var value: Double
    public var unit: String
    public init(id: String, title: String, value: Double, unit: String) { self.id = id; self.title = title; self.value = value; self.unit = unit }
}

public struct StaticCurvePoint: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

public struct StaticMeasurementResult: Codable, Equatable, Sendable {
    public var values: [StaticResultValue]
    public var curve: [StaticCurvePoint]?
    public var notes: [String]
    public init(values: [StaticResultValue], curve: [StaticCurvePoint]? = nil, notes: [String] = []) { self.values = values; self.curve = curve; self.notes = notes }
}

public struct StaticMeasurementRecord: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var date: Date
    public var feature: StaticFeatureID
    public var input: StaticMeasurementInput
    public var result: StaticMeasurementResult
    public var origin: DataOrigin
    public var protocolID: String
    public init(id: UUID = UUID(), date: Date = Date(), feature: StaticFeatureID, input: StaticMeasurementInput, result: StaticMeasurementResult, origin: DataOrigin = .manual, protocolID: String? = nil) {
        self.id = id; self.date = date; self.feature = feature; self.input = input; self.result = result
        self.origin = origin; self.protocolID = protocolID ?? feature.protocolID
    }
}

public enum StaticCatalogError: LocalizedError {
    case missingResource, unsupportedVersion, incompleteCatalog
    public var errorDescription: String? {
        switch self {
        case .missingResource: return "本地静态测量目录未加载。"
        case .unsupportedVersion: return "静态测量目录版本不匹配。"
        case .incompleteCatalog: return "静态测量目录条目或来源不完整。"
        }
    }
}

public enum StaticFeatureCatalog {
    private static let bundled: Result<[StaticFeatureMetadata], Error> = Result {
        guard let url = Bundle.main.url(forResource: "StaticBodyCatalog", withExtension: "json")
            ?? Bundle.main.url(forResource: "StaticBodyCatalog", withExtension: "json", subdirectory: "Resources") else { throw StaticCatalogError.missingResource }
        return try load(data: Data(contentsOf: url))
    }
    public static var all: [StaticFeatureMetadata] { (try? bundled.get()) ?? [] }
    public static var loadingError: String? {
        if case .failure(let error) = bundled { return error.localizedDescription }
        return nil
    }
    public static func metadata(for feature: StaticFeatureID) -> StaticFeatureMetadata? { all.first { $0.id == feature } }
    public static func load(data: Data) throws -> [StaticFeatureMetadata] {
        let document = try JSONDecoder().decode(CatalogDocument.self, from: data)
        guard document.version == "static-only" else { throw StaticCatalogError.unsupportedVersion }
        guard document.rows.count == StaticFeatureID.allCases.count,
              Set(document.rows.map(\.id)) == Set(StaticFeatureID.allCases.map(\.rawValue)),
              Set(document.sources.map(\.id)).count == document.sources.count else { throw StaticCatalogError.incompleteCatalog }
        let sources = Dictionary(uniqueKeysWithValues: document.sources.map { ($0.id, $0) })
        return try document.rows.map { row in
            guard let id = StaticFeatureID(rawValue: row.id), row.source_ids.allSatisfy({ sources[$0] != nil }) else { throw StaticCatalogError.incompleteCatalog }
            var guide = "本机保存手工输入与采集上下文；原表采集要求：" + row.measurement
            if id == .sm08 || id == .sm09 { guide += "本版也可人工录入照片点位并保存侧别；点位投影估计不等于骨长。是否由模型初标以采集上下文为准，不补造模型输出。" }
            if id == .sm10 { guide += "本版手工表单固定右手，手掌平放、手指自然并拢；腕参考线取远端腕横纹，掌宽取掌指关节区横宽、不含拇指。这些固定测点为产品口径。" }
            if id == .sm11 { guide += "本版手工表单固定右足，自然承重足印轮廓，用平面直尺量足跟至最远趾端及前足最大宽；不混用足背照片。" }
            return StaticFeatureMetadata(id: id, title: row.function, category: row.category ?? row.group ?? "探索与质控", group: row.group ?? row.mode, data: row.data, formula: row.formula, measurementGuide: guide, interpretation: row.interpretation, limitations: row.limitations, evidence: row.evidence ?? "", validation: row.validation ?? "", talentInference: row.talent_inference ?? "", route: row.route ?? "", mode: row.mode, type: row.type, formulaType: row.formula_type ?? "", sourceIDs: row.source_ids, sourceReferences: row.source_ids.compactMap { sources[$0] }.map { StaticSourceReference(id: $0.id, title: $0.title, url: $0.url, evidence: $0.evidence ?? $0.finding ?? "", limitations: $0.limits ?? "", access: $0.access ?? "") }, inputFields: inputFields(for: id), availability: id == .h03 ? .requiresReferenceLibrary : .available)
        }
    }

    public static let targetMetrics: [StaticTargetMetric] = [
        StaticTargetMetric(id: "armSpanRatio", title: "臂展比例", feature: .sm02),
        StaticTargetMetric(id: "relativeShoulderWidth", title: "相对肩宽", feature: .sm03),
        StaticTargetMetric(id: "shoulderWaistWidthRatio", title: "肩腰宽比", feature: .sm04),
        StaticTargetMetric(id: "waistHipWidthRatio", title: "腰臀宽比", feature: .sm04),
        StaticTargetMetric(id: "widthDepthRatio", title: "同高度宽深比", feature: .sm05),
        StaticTargetMetric(id: "sittingHeightRatio", title: "坐高比", feature: .sm07),
        StaticTargetMetric(id: "legBodyRatio", title: "下肢比例", feature: .sm07),
        StaticTargetMetric(id: "foreUpperRatio", title: "前臂/上臂投影比", feature: .sm08),
        StaticTargetMetric(id: "distProxRatio", title: "远端/近端投影比", feature: .sm09),
        StaticTargetMetric(id: "handAspectRatio", title: "手宽长比", feature: .sm10),
        StaticTargetMetric(id: "footAspectRatio", title: "足宽长比", feature: .sm11),
        StaticTargetMetric(id: "waistHipGirthRatio", title: "腰臀围比", feature: .sm12),
        StaticTargetMetric(id: "relativeChestGirth", title: "相对胸围", feature: .sm12),
        StaticTargetMetric(id: "relativeWaistGirth", title: "相对腰围", feature: .sm12),
        StaticTargetMetric(id: "relativeHipGirth", title: "相对臀围", feature: .sm12),
        StaticTargetMetric(id: "relativeUpperArmGirth", title: "相对上臂围", feature: .sm12),
        StaticTargetMetric(id: "relativeThighGirth", title: "相对大腿围", feature: .sm12),
        StaticTargetMetric(id: "relativeCalfGirth", title: "相对小腿围", feature: .sm12)
    ]

    public static func inputFields(for feature: StaticFeatureID) -> [StaticInputField] {
        let height = number("heightCM", "身高", "cm", 50...260)
        let shoulder = number("shoulderWidthCM", "外轮廓肩宽", "cm", 10...100)
        let waist = number("waistWidthCM", "固定层面腰宽", "cm", 5...100)
        let hip = number("hipWidthCM", "臀部最大宽", "cm", 10...120)
        let scale = number("scaleCMPerPixel", "同平面尺度", "cm/px", 0.000001...100)
        let side = StaticInputField(key: "side", title: "身体侧别", kind: .text, options: ["左", "右"])
        let healthSide = StaticInputField(key: "side", title: "部位侧别", kind: .text, options: ["左", "右", "双侧", "中线", "未知"])
        let calibration = StaticInputField(key: "calibrationStatus", title: "尺度适用条件", kind: .text, options: ["已校正且共面", "仅像素"])
        switch feature {
        case .sm01: return [number("referenceLengthCM", "参照物实长", "cm", 0.001...10000, optional: true), number("referencePixels", "参照像素长度", "px", 0.001...1000000, optional: true), coordinate("groundY", "地面 y"), coordinate("vertexY", "头顶 y"), calibration]
        case .sm02: return [number("armSpanCM", "臂展", "cm", 50...300), height]
        case .sm03: return [shoulder, height]
        case .sm04: return [shoulder, waist, hip, text("waistLevel", "固定腰测量线说明")]
        case .sm05: return [number("widthCM", "正面轮廓宽", "cm", 0.1...150), number("depthCM", "同高度侧面深", "cm", 0.1...150), text("level", "共同截面高度说明")]
        case .sm07: return [height, number("sittingHeightCM", "座面至头顶坐高", "cm", 20...160)]
        case .sm08: return [coordinate("shoulderX", "肩 x"), coordinate("shoulderY", "肩 y"), coordinate("elbowX", "肘 x"), coordinate("elbowY", "肘 y"), coordinate("wristX", "腕 x"), coordinate("wristY", "腕 y"), optionalScale(scale), side, calibration]
        case .sm09:
            var hipX = coordinate("hipX", "髋 x"), hipY = coordinate("hipY", "髋 y")
            hipX.optional = true; hipY.optional = true
            return [hipX, hipY, coordinate("kneeX", "膝 x"), coordinate("kneeY", "膝 y"), coordinate("ankleX", "踝 x"), coordinate("ankleY", "踝 y"), optionalScale(scale), side, calibration]
        case .sm10: return [number("handLengthCM", "右手长度", "cm", 5...35), number("handWidthCM", "右手掌宽", "cm", 2...20)]
        case .sm11: return [number("footLengthCM", "右足足印长度", "cm", 10...45), number("footWidthCM", "右足前掌宽", "cm", 3...25)]
        case .sm12:
            return [height] + [("chestGirthCM", "胸围"), ("waistGirthCM", "腰围"), ("hipGirthCM", "臀围"), ("upperArmGirthCM", "上臂围"), ("thighGirthCM", "大腿围"), ("calfGirthCM", "小腿围")].map { number($0.0, $0.1, "cm", 0.1...300, optional: true) } + [text("measurementPoints", "已填围度的测点、姿势与呼吸说明")]
        case .sm13: return [number("weightKG", "体重", "kg", 1...500), height, text("weighingContext", "衣着与称量时段", optional: true)]
        case .sm16: return [coordinate("headY", "头顶 y"), number("heightPixels", "头顶至足底像素身高", "px", 0.001...1000000), series("heights", "各层面 y（向上）", "px"), series("leftX", "各层面左边界 x", "px"), series("rightX", "各层面右边界 x", "px")]
        case .sr01:
            var state = calibration; state.optional = true
            return [coordinate("leftX", "身体左肩 x"), coordinate("leftY", "身体左肩 y"), coordinate("rightX", "身体右肩 x"), coordinate("rightY", "身体右肩 y"), optionalScale(scale), state]
        case .sr02: return [coordinate("leftEarX", "身体左耳垂 x"), coordinate("leftEarY", "身体左耳垂 y"), coordinate("rightEarX", "身体右耳垂 x"), coordinate("rightEarY", "身体右耳垂 y")]
        case .sr03:
            var state = calibration; state.optional = true
            return [coordinate("upperLeftX", "腋下层面左 x"), coordinate("upperRightX", "腋下层面右 x"), coordinate("waistLeftX", "肚脐层面左 x"), coordinate("waistRightX", "肚脐层面右 x"), coordinate("upperY", "腋下层面 y"), coordinate("waistY", "肚脐层面 y"), optionalScale(scale), state]
        case .sr04: return [series("leftGirthsCM", "左侧同部位复测围度", "cm", 0.1...300), series("rightGirthsCM", "右侧同部位复测围度", "cm", 0.1...300), text("site", "同侧测量层面与放松状态说明")]
        case .sr05: return [number("eventCount", "该部位既往事件次数", "次", 0...10000, integer: true), text("site", "部位"), healthSide, text("eventDescription", "自报事件/已诊断与康复背景", optional: true), date("lastEventDate", "最近事件日期", optional: true), date("returnToSportDate", "恢复运动日期", optional: true)]
        case .sr06: return [number("restingNRS", "现在静息疼痛 NRS", "分", 0...10, integer: true), text("site", "部位"), healthSide, text("duration", "持续多久", optional: true), text("dailyImpact", "是否影响日常活动", optional: true)]
        case .h01: return [number("widthCM", "同高度正面宽", "cm", 0.1...150), number("depthCM", "同高度侧面深", "cm", 0.1...150), text("level", "共同截面高度说明")]
        case .h02, .h03: return []
        case .q01: return [number("referenceLengthCM", "参照物实长", "cm", 0.001...10000, optional: true), number("referencePixels", "参照像素长度", "px", 0.001...1000000, optional: true), number("distancePixels", "待测两点像素距离", "px", 0.001...1000000), calibration]
        case .q02: return [series("repeats", "至少三次独立重测", "", nil), StaticInputField(key: "measurementType", title: "重测量纲", kind: .text, options: ["长度", "角度"]), text("metricName", "重测指标与同次采集说明")]
        }
    }

    private static func number(_ key: String, _ title: String, _ unit: String, _ range: ClosedRange<Double>, optional: Bool = false, integer: Bool = false) -> StaticInputField { StaticInputField(key: key, title: title, unit: unit, optional: optional, range: range, isInteger: integer) }
    private static func coordinate(_ key: String, _ title: String) -> StaticInputField { StaticInputField(key: key, title: title, unit: "px", range: -1000000...1000000) }
    private static func series(_ key: String, _ title: String, _ unit: String, _ range: ClosedRange<Double>? = -1000000...1000000) -> StaticInputField { StaticInputField(key: key, title: title, unit: unit, kind: .series, range: range) }
    private static func text(_ key: String, _ title: String, optional: Bool = false) -> StaticInputField { StaticInputField(key: key, title: title, kind: .text, optional: optional) }
    private static func date(_ key: String, _ title: String, optional: Bool = false) -> StaticInputField { StaticInputField(key: key, title: title, kind: .date, optional: optional) }
    private static func optionalScale(_ scale: StaticInputField) -> StaticInputField { var field = scale; field.optional = true; return field }

    private struct CatalogDocument: Decodable { let version: String; let rows: [CatalogRow]; let sources: [CatalogSource] }
    private struct CatalogRow: Decodable {
        let id: String; let function: String; let category: String?; let group: String?; let data: String
        let formula: String; let measurement: String; let interpretation: String; let limitations: String
        let evidence: String?; let validation: String?; let talent_inference: String?; let route: String?
        let mode: String; let type: String; let formula_type: String?; let source_ids: [String]
    }
    private struct CatalogSource: Decodable { let id: String; let title: String; let url: String?; let evidence: String?; let finding: String?; let limits: String?; let access: String? }
}
