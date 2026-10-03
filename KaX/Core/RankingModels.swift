import Foundation

public enum RankingCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case structure, shape
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .structure: return "尺寸比例"
        case .shape: return "当前形体"
        }
    }
}

public struct RankingInputField: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let unit: String
    public let allowedRange: ClosedRange<Double>
    public let isInteger: Bool
    public init(id: String, title: String, unit: String, allowedRange: ClosedRange<Double>, isInteger: Bool = false) {
        self.id = id; self.title = title; self.unit = unit; self.allowedRange = allowedRange; self.isInteger = isInteger
    }
}

public struct RankingSource: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let url: String?
    public let reportSection: String
    public var sourceURL: String? { url }
    public init(id: String, title: String, url: String?, reportSection: String) {
        self.id = id; self.title = title; self.url = url; self.reportSection = reportSection
    }
}

public enum RankingMetric: String, Codable, CaseIterable, Identifiable, Sendable {
    case armSpanRatio, relativeShoulderWidth, legBodyRatio, shoulderWaistWidthRatio
    case waistHipWidthRatio, waistHipGirthRatio, handAspectRatio, footAspectRatio

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .armSpanRatio: return "臂展比例"
        case .relativeShoulderWidth: return "相对肩宽"
        case .legBodyRatio: return "下肢比例"
        case .shoulderWaistWidthRatio: return "肩腰宽比"
        case .waistHipWidthRatio: return "腰臀宽比"
        case .waistHipGirthRatio: return "腰臀围比"
        case .handAspectRatio: return "手宽长比"
        case .footAspectRatio: return "足宽长比"
        }
    }
    public var category: RankingCategory {
        switch self {
        case .armSpanRatio, .legBodyRatio, .handAspectRatio, .footAspectRatio: return .structure
        case .relativeShoulderWidth, .shoulderWaistWidthRatio, .waistHipWidthRatio, .waistHipGirthRatio: return .shape
        }
    }
    public var unit: String { "倍" }
    public var displayPrecision: Int { 2 }
    /// This version accepts manually recorded dimensions, not automatic photo or device output.
    public var protocolID: String { "kax.static.manual.\(rawValue).v1" }
    public var inputFields: [RankingInputField] {
        switch self {
        case .armSpanRatio: return [Self.field("armSpanCM", "臂展", 50...300), Self.field("heightCM", "身高", 50...260)]
        case .relativeShoulderWidth: return [Self.field("shoulderWidthCM", "外轮廓肩宽", 10...100), Self.field("heightCM", "身高", 50...260)]
        case .legBodyRatio: return [Self.field("heightCM", "身高", 50...260), Self.field("sittingHeightCM", "坐高", 20...160)]
        case .shoulderWaistWidthRatio: return [Self.field("shoulderWidthCM", "外轮廓肩宽", 10...100), Self.field("waistWidthCM", "固定测点腰宽", 5...100)]
        case .waistHipWidthRatio: return [Self.field("waistWidthCM", "固定测点腰宽", 5...100), Self.field("hipWidthCM", "臀部最大宽", 10...120)]
        case .waistHipGirthRatio: return [Self.field("waistGirthCM", "腰围", 30...300), Self.field("hipGirthCM", "臀围", 30...300)]
        case .handAspectRatio: return [Self.field("handWidthCM", "右手掌宽", 2...20), Self.field("handLengthCM", "右手长度", 5...35)]
        case .footAspectRatio: return [Self.field("footWidthCM", "右足前掌宽", 3...25), Self.field("footLengthCM", "右足长度", 10...45)]
        }
    }
    public var formula: String {
        switch self {
        case .armSpanRatio: return "臂展比例 = 臂展 ÷ 身高"
        case .relativeShoulderWidth: return "相对肩宽 = 外轮廓肩宽 ÷ 身高"
        case .legBodyRatio: return "下肢比例 =（身高 − 坐高）÷ 身高"
        case .shoulderWaistWidthRatio: return "肩腰宽比 = 外轮廓肩宽 ÷ 固定测点腰宽"
        case .waistHipWidthRatio: return "腰臀宽比 = 固定测点腰宽 ÷ 臀部最大宽"
        case .waistHipGirthRatio: return "腰臀围比 = 腰围 ÷ 臀围"
        case .handAspectRatio: return "手宽长比 = 规定位置掌宽 ÷ 手长"
        case .footAspectRatio: return "足宽长比 = 前足规定区域最大宽 ÷ 足长"
        }
    }
    public var measurementGuide: String {
        let manual = "本版手工录入同次、同定义的 cm 尺寸，尚未接入照片自动提取或设备采集。"
        let guide: String
        switch self {
        case .armSpanRatio: guide = "双臂水平展开、肘伸直、手指伸展且与肩同平面，测两侧中指尖距离；同次测站高。"
        case .relativeShoulderWidth: guide = "自然站立、肩放松、手臂稍离躯干；测肩部区间左右三角肌外侧轮廓最大水平宽度，保持同一区间，再测站高。"
        case .legBodyRatio: guide = "测站高；坐直于水平硬质凳、脚有支撑，从座面量至头顶得到坐高。坐高不是从地面到头顶，也不能用裆点或髋点替代。"
        case .shoulderWaistWidthRatio: guide = "自然站立、自然呼气；肩宽取三角肌外缘水平最大宽。腰线固定为最低可触肋缘与髂嵴上缘中点的水平线，按此线量左右外轮廓宽；本腰线是固定的首版产品口径。"
        case .waistHipWidthRatio: guide = "自然站立、自然呼气；腰线固定为最低可触肋缘与髂嵴上缘中点的水平线，量左右外轮廓宽，再量臀部最大水平宽。本腰线是固定的首版产品口径。"
        case .waistHipGirthRatio: guide = "非拉伸软尺水平绕行、不挤压皮肤；腰围固定在右侧髂嵴上缘水平、自然呼气末，臀围在臀部最突出水平，复测保持同一测点。围度独立于照片宽度。"
        case .handAspectRatio: guide = "首版固定右手：手掌平放、手指自然并拢；手长从腕部远端横纹参考线中点至最长指尖，掌宽为掌指关节区左右最大横宽（不含拇指）。测点与侧别是本版产品口径，不与其他手长定义混榜。"
        case .footAspectRatio: guide = "首版固定右足：赤足自然承重，在纸上描边后测足跟至最远趾端轴向长度，以及前足最大宽。足印与俯拍足背分别定义，本榜采用同一足印口径。"
        }
        let widthNote: String
        switch self {
        case .relativeShoulderWidth, .shoulderWaistWidthRatio, .waistHipWidthRatio:
            widthNote = "宽度取两侧测点之间的水平直线距离，不沿皮肤曲面绕量。"
        default: widthNote = ""
        }
        return manual + guide + widthNote
    }
    public var interpretation: String {
        switch self {
        case .armSpanRatio: return "数值更大表示臂展相对身高更长。"
        case .relativeShoulderWidth: return "数值更大表示可见肩部外轮廓相对身高更宽。"
        case .legBodyRatio: return "数值更大表示坐高法构造的相对下肢长度占身高比例更大。"
        case .shoulderWaistWidthRatio: return "数值更大表示正面肩部外轮廓相对腰部更宽。"
        case .waistHipWidthRatio: return "数值更大表示固定腰线的轮廓宽度相对臀部更宽。"
        case .waistHipGirthRatio: return "数值更大表示腰围相对臀围更大。"
        case .handAspectRatio: return "数值更大表示右手掌形相对更宽。"
        case .footAspectRatio: return "数值更大表示右足足印相对更宽。"
        }
    }
    public var limitations: String {
        let ranking = "排序仅比较尺寸特征大小，不表示优劣、百分位、遗传天赋、增肌潜力或受伤概率。输入范围仅用于防止明显录入错误，不是研究阈值。"
        let limit: String
        switch self {
        case .armSpanRatio: limit = "肩胛姿态、屈肘或手臂离开平面会影响数值；臂展长不等于力量强或某项目必然优秀。"
        case .relativeShoulderWidth: limit = "轮廓包含肌肉与皮下组织；不是肩峰宽、锁骨长度或骨架宽，姿势、肌肉和脂肪都可改变结果。"
        case .legBodyRatio: limit = "含姿势、骨盆位置与软组织影响，不等于股骨加胫骨骨长；裆点替代坐高会改变定义。"
        case .shoulderWaistWidthRatio, .waistHipWidthRatio: limit = "宽比不是围度比，不能套围度的医学阈值，亦没有经普适验证的黄金比例。"
        case .waistHipGirthRatio: limit = "围度包含肌肉、脂肪与骨；本榜描述当前形体，不能替代健康评估或跨测点阈值。"
        case .handAspectRatio: limit = "手部外形不代表握力、肌腱强度或攀爬天赋；软组织边界不是骨宽。"
        case .footAspectRatio: limit = "不能由长宽判足弓、足底压力、跟腱力臂或跑步伤风险；侧别与承重状态必须一致。"
        }
        return limit + ranking
    }
    public var sourceReferences: [RankingSource] {
        let row: String
        let title: String
        let sources: [RankingSource]
        switch self {
        case .armSpanRatio:
            row = "SM02"; title = "臂展与身高比例"; sources = [Self.q01, Self.q02, Self.ss05]
        case .relativeShoulderWidth:
            row = "SM03"; title = "外轮廓肩宽与肩宽身高比"; sources = [Self.q01, Self.q02, Self.ss04]
        case .legBodyRatio:
            row = "SM07"; title = "坐高、相对下肢长度"; sources = [Self.q02, Self.ss04]
        case .shoulderWaistWidthRatio, .waistHipWidthRatio:
            row = "SM04"; title = "肩腰与腰臀外轮廓比例"; sources = [Self.q01, Self.q02]
        case .waistHipGirthRatio:
            row = "SM12"; title = "软尺围度与外形分布"; sources = [Self.ss03]
        case .handAspectRatio:
            row = "SM10"; title = "静态手部长度和宽度"; sources = [Self.q01, Self.q02, Self.ss04]
        case .footAspectRatio:
            row = "SM11"; title = "静态足部长度和宽度"; sources = [Self.q01, Self.q02, Self.ss04]
        }
        return [RankingSource(id: row, title: title, url: nil, reportSection: "静态功能公式表（static-only）\(row)；健身研究·表观")]
            + sources.map { RankingSource(id: $0.id, title: $0.title, url: $0.url, reportSection: "\(row) 来源索引 \($0.id)：几何/人工测量依据，非天赋评分验证") }
    }

    public func formattedValue(_ value: Double) -> String { String(format: "%.*f", displayPrecision, value) }
    public func calculatedValue(from values: [String: Double]) throws -> Double {
        guard Set(values.keys) == Set(inputFields.map(\.id)) else { throw RankingValidationError.invalidFields }
        for field in inputFields {
            guard let value = values[field.id], value.isFinite, field.allowedRange.contains(value),
                  !field.isInteger || value.rounded() == value else { throw RankingValidationError.invalidValue(field.title) }
        }
        let result: Double
        switch self {
        case .armSpanRatio: result = values["armSpanCM"]! / values["heightCM"]!
        case .relativeShoulderWidth: result = values["shoulderWidthCM"]! / values["heightCM"]!
        case .legBodyRatio:
            let height = values["heightCM"]!, sittingHeight = values["sittingHeightCM"]!
            guard sittingHeight < height else { throw RankingValidationError.invalidValue("坐高应小于身高") }
            result = (height - sittingHeight) / height
        case .shoulderWaistWidthRatio: result = values["shoulderWidthCM"]! / values["waistWidthCM"]!
        case .waistHipWidthRatio: result = values["waistWidthCM"]! / values["hipWidthCM"]!
        case .waistHipGirthRatio: result = values["waistGirthCM"]! / values["hipGirthCM"]!
        case .handAspectRatio:
            guard values["handWidthCM"]! < values["handLengthCM"]! else { throw RankingValidationError.invalidValue("掌宽应小于手长") }
            result = values["handWidthCM"]! / values["handLengthCM"]!
        case .footAspectRatio:
            guard values["footWidthCM"]! < values["footLengthCM"]! else { throw RankingValidationError.invalidValue("足宽应小于足长") }
            result = values["footWidthCM"]! / values["footLengthCM"]!
        }
        guard result.isFinite, result > 0 else { throw RankingValidationError.invalidFields }
        return result
    }

    private static func field(_ id: String, _ title: String, _ range: ClosedRange<Double>) -> RankingInputField {
        RankingInputField(id: id, title: title, unit: "cm", allowedRange: range)
    }
    private static let q01 = RankingSource(id: "Q01", title: "OpenCV：ArUco / ChArUco 相机标定", url: "https://docs.opencv.org/4.x/da/d13/tutorial_aruco_calibration.html", reportSection: "来源索引 Q01")
    private static let q02 = RankingSource(id: "Q02", title: "Kinovea：线标定与平面标定", url: "https://www.kinovea.org/help/en/measurement/calibration.html", reportSection: "来源索引 Q02")
    private static let ss03 = RankingSource(id: "SS03", title: "CDC/NCHS NHANES Anthropometry Procedures Manual", url: "https://stacks.cdc.gov/view/cdc/127207/cdc_127207_DS1.pdf", reportSection: "来源索引 SS03")
    private static let ss04 = RankingSource(id: "SS04", title: "ANSUR II 官方来源与测量手册索引；测点细节尚待复核", url: "https://www.openlab.psu.edu/ansur2/", reportSection: "来源索引 SS04")
    private static let ss05 = RankingSource(id: "SS05", title: "Ferland：59 名男性力量举者的横断面人体测量关联", url: "https://pubmed.ncbi.nlm.nih.gov/33414873/", reportSection: "来源索引 SS05")
}

public enum RankingValidationError: LocalizedError, Equatable {
    case invalidFields, invalidValue(String), protocolMismatch, invalidDate, notCurrentUser, originMismatch, recordIdentityMismatch
    public var errorDescription: String? {
        switch self {
        case .invalidFields: return "请填写该指标全部且对应的测量数据。"
        case .invalidValue(let field): return "\(field)的测量数值无效。"
        case .protocolMismatch: return "该测量协议与当前榜单不匹配。"
        case .invalidDate: return "测量日期无效。"
        case .notCurrentUser: return "只能保存自己的测量。"
        case .originMismatch: return "本版榜单仅接受同定义的手工测量或明确标注的演示样本。"
        case .recordIdentityMismatch: return "该记录标识已属于另一条测量，未覆盖。"
        }
    }
}

public struct RankingMeasurement: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var personID: String
    public var metric: RankingMetric
    public var values: [String: Double]
    public var protocolID: String
    public var date: Date
    public var origin: DataOrigin
    public var sourceRecordID: UUID?
    public init(id: UUID = UUID(), personID: String, metric: RankingMetric, values: [String: Double], protocolID: String? = nil, date: Date = Date(), origin: DataOrigin, sourceRecordID: UUID? = nil) {
        self.id = id; self.personID = personID; self.metric = metric; self.values = values
        self.protocolID = protocolID ?? metric.protocolID; self.date = date; self.origin = origin
        self.sourceRecordID = sourceRecordID
    }
    public func calculatedValue() throws -> Double {
        guard protocolID == metric.protocolID else { throw RankingValidationError.protocolMismatch }
        guard origin == .manual || origin == .demo else { throw RankingValidationError.originMismatch }
        guard date.timeIntervalSince1970.isFinite else { throw RankingValidationError.invalidDate }
        return try metric.calculatedValue(from: values)
    }
}

public struct EvidenceRankEntry: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var initials: String
    public var value: Double
    public var position: Int
    public var isCurrentUser: Bool
    public var measurement: RankingMeasurement
    public init(id: String, name: String, initials: String, value: Double, position: Int, isCurrentUser: Bool, measurement: RankingMeasurement) {
        self.id = id; self.name = name; self.initials = initials; self.value = value; self.position = position; self.isCurrentUser = isCurrentUser; self.measurement = measurement
    }
}
