import Foundation

public enum StaticMeasurementError: LocalizedError, Equatable {
    case missing(String), invalid(String), unexpectedFields, nonFiniteResult, referenceLibraryUnavailable
    public var errorDescription: String? {
        switch self {
        case .missing(let field): return "请填写\(field)，缺失数据不补零。"
        case .invalid(let field): return "\(field)无效，未计算。"
        case .unexpectedFields: return "输入字段与本项测量定义不匹配。"
        case .nonFiniteResult: return "输入导致结果无法可靠计算。"
        case .referenceLibraryUnavailable: return "真实同协议参照库尚未接入，暂不能计算百分位；演示数据不作为参照人群。"
        }
    }
}

public enum StaticMeasurementCalculator {
    public static func calculate(feature: StaticFeatureID, input: StaticMeasurementInput, now: Date = Date()) throws -> StaticMeasurementResult {
        guard feature != .h03 else { throw StaticMeasurementError.referenceLibraryUnavailable }
        guard now.timeIntervalSince1970.isFinite else { throw StaticMeasurementError.invalid("当前日期") }
        try validate(feature: feature, input: input)
        let v = input.values
        func value(_ id: String, _ title: String, _ number: Double, _ unit: String) -> StaticResultValue {
            StaticResultValue(id: id, title: title, value: number, unit: unit)
        }
        func pairedReferenceScale() throws -> Double? {
            guard (v["referenceLengthCM"] != nil) == (v["referencePixels"] != nil) else { throw StaticMeasurementError.invalid("参照物实长与像素长度应同时填写") }
            guard context("calibrationStatus", input) == "已校正且共面" else { return nil }
            guard let length = v["referenceLengthCM"], let pixels = v["referencePixels"] else { throw StaticMeasurementError.missing("参照物实长与像素长度") }
            return length / pixels
        }
        func pointScale() throws -> Double? {
            guard context("calibrationStatus", input) == "已校正且共面" else { return nil }
            guard let scale = v["scaleCMPerPixel"] else { throw StaticMeasurementError.missing("同平面尺度") }
            return scale
        }
        var result: StaticMeasurementResult
        switch feature {
        case .sm01, .q01:
            let pixels = feature == .sm01 ? abs(v["groundY"]! - v["vertexY"]!) : v["distancePixels"]!
            guard pixels > 0 else { throw StaticMeasurementError.invalid("两待测点距离") }
            var values = [value(feature == .sm01 ? "heightPixels" : "distancePixels", feature == .sm01 ? "投影身高像素" : "两点像素距离", pixels, "px")]
            if let scale = try pairedReferenceScale() {
                values += [value("scaleCMPerPixel", "同平面尺度", scale, "cm/px"), value(feature == .sm01 ? "heightCM" : "lengthCM", feature == .sm01 ? "投影身高" : "同平面长度", scale * pixels, "cm")]
            }
            result = StaticMeasurementResult(values: values, notes: ["厘米输出仅适用于已校正畸变且目标与参照共面的条件；仅像素模式不推断人体实长。"])
        case .sm02:
            result = StaticMeasurementResult(values: [value("armSpanCM", "臂展", v["armSpanCM"]!, "cm"), value("armSpanRatio", "臂展比例", v["armSpanCM"]! / v["heightCM"]!, "倍"), value("armSpanDifferenceCM", "臂展 − 身高", v["armSpanCM"]! - v["heightCM"]!, "cm")])
        case .sm03:
            result = StaticMeasurementResult(values: [value("shoulderWidthCM", "外轮廓肩宽", v["shoulderWidthCM"]!, "cm"), value("relativeShoulderWidth", "相对肩宽", v["shoulderWidthCM"]! / v["heightCM"]!, "倍")])
        case .sm04:
            result = StaticMeasurementResult(values: [value("shoulderWaistWidthRatio", "肩腰宽比", v["shoulderWidthCM"]! / v["waistWidthCM"]!, "倍"), value("waistHipWidthRatio", "腰臀宽比", v["waistWidthCM"]! / v["hipWidthCM"]!, "倍")], notes: ["这是固定测量线的轮廓宽度比，不是围度比。"])
        case .sm05:
            result = StaticMeasurementResult(values: [value("widthDepthRatio", "同高度宽深比", v["widthCM"]! / v["depthCM"]!, "倍")])
        case .sm07:
            let height = v["heightCM"]!, sitting = v["sittingHeightCM"]!
            guard sitting < height else { throw StaticMeasurementError.invalid("坐高必须小于身高") }
            result = StaticMeasurementResult(values: [value("sittingHeightCM", "坐高", sitting, "cm"), value("relativeLegLengthCM", "相对下肢长度", height - sitting, "cm"), value("sittingHeightRatio", "坐高比", sitting / height, "倍"), value("legBodyRatio", "下肢比例", (height - sitting) / height, "倍")])
        case .sm08, .sm09:
            let proximal = feature == .sm08 ? "shoulder" : "hip"
            let joint = feature == .sm08 ? "elbow" : "knee"
            let distal = feature == .sm08 ? "wrist" : "ankle"
            let distalPixels = hypot(v["\(joint)X"]! - v["\(distal)X"]!, v["\(joint)Y"]! - v["\(distal)Y"]!)
            guard distalPixels > 0 else { throw StaticMeasurementError.invalid("远端两个点不能重合") }
            let scale = try pointScale()
            let unit = scale == nil ? "px" : "cm"
            let factor = scale ?? 1
            var values = [value(feature == .sm08 ? "foreLength\(scale == nil ? "Pixels" : "CM")" : "distLength\(scale == nil ? "Pixels" : "CM")", feature == .sm08 ? "前臂点位投影长度" : "膝踝点位投影长度", distalPixels * factor, unit)]
            guard (v["\(proximal)X"] != nil) == (v["\(proximal)Y"] != nil) else { throw StaticMeasurementError.invalid("近端点 x/y 应同时填写") }
            if let x = v["\(proximal)X"], let y = v["\(proximal)Y"] {
                let proximalPixels = hypot(x - v["\(joint)X"]!, y - v["\(joint)Y"]!)
                guard proximalPixels > 0 else { throw StaticMeasurementError.invalid("近端两个点不能重合") }
                values.insert(value(feature == .sm08 ? "upperLength\(scale == nil ? "Pixels" : "CM")" : "proxLength\(scale == nil ? "Pixels" : "CM")", feature == .sm08 ? "上臂点位投影长度" : "髋膝点位投影长度", proximalPixels * factor, unit), at: 0)
                values.append(value(feature == .sm08 ? "foreUpperRatio" : "distProxRatio", feature == .sm08 ? "前臂/上臂投影比" : "远端/近端投影比", distalPixels / proximalPixels, "倍"))
            }
            result = StaticMeasurementResult(values: values, notes: ["点位投影估计；不是骨长、真实关节中心或肌肉力臂。侧别与模型初标/人工修正情况保存在输入上下文。", scale == nil ? "尺度未确认，只报告 px 与可计算的无量纲比值。" : "尺度条件已声明确认；厘米结果仍为点位投影估计。"])
        case .sm10, .sm11:
            if let side = context("side", input), side != "右" { throw StaticMeasurementError.invalid("本版手足表单固定右侧") }
            let length = v[feature == .sm10 ? "handLengthCM" : "footLengthCM"]!
            let width = v[feature == .sm10 ? "handWidthCM" : "footWidthCM"]!
            guard width < length else { throw StaticMeasurementError.invalid("宽度应小于长度") }
            result = StaticMeasurementResult(values: [value(feature == .sm10 ? "handLengthCM" : "footLengthCM", feature == .sm10 ? "右手长度" : "右足足印长度", length, "cm"), value(feature == .sm10 ? "handWidthCM" : "footWidthCM", feature == .sm10 ? "右掌宽" : "右足前掌宽", width, "cm"), value(feature == .sm10 ? "handAspectRatio" : "footAspectRatio", feature == .sm10 ? "手宽长比" : "足宽长比", width / length, "倍")], notes: [feature == .sm10 ? "右手平放、手指自然并拢；固定腕参考线与掌宽测点为产品口径。" : "右足自然承重的足印轮廓；不混用足背俯拍长度。"])
        case .sm12:
            let fields = [("chestGirthCM", "relativeChestGirth", "相对胸围"), ("waistGirthCM", "relativeWaistGirth", "相对腰围"), ("hipGirthCM", "relativeHipGirth", "相对臀围"), ("upperArmGirthCM", "relativeUpperArmGirth", "相对上臂围"), ("thighGirthCM", "relativeThighGirth", "相对大腿围"), ("calfGirthCM", "relativeCalfGirth", "相对小腿围")]
            var values = fields.compactMap { field in v[field.0].map { value(field.1, field.2, $0 / v["heightCM"]!, "倍") } }
            guard !values.isEmpty else { throw StaticMeasurementError.missing("至少一项实测围度") }
            if let waist = v["waistGirthCM"], let hip = v["hipGirthCM"] { values.append(value("waistHipGirthRatio", "腰臀围比", waist / hip, "倍")) }
            result = StaticMeasurementResult(values: values, notes: ["缺失围度不补零；只为实际填写的围度计算比例。"])
        case .sm13:
            let metres = v["heightCM"]! / 100
            result = StaticMeasurementResult(values: [value("bmi", "BMI", v["weightKG"]! / (metres * metres), "kg/m²")], notes: ["BMI 不区分肌肉与脂肪，不作为运动天赋评价。"])
        case .sm16:
            let heights = input.series["heights"]!, left = input.series["leftX"]!, right = input.series["rightX"]!
            guard heights.count >= 2, heights.count == left.count, heights.count == right.count,
                  Set(heights).count == heights.count else { throw StaticMeasurementError.invalid("三列轮廓数组须等长、至少两层，且高度不能重复") }
            let h = v["heightPixels"]!, head = v["headY"]!
            var curve: [StaticCurvePoint] = []
            for i in heights.indices {
                let eta = (head - heights[i]) / h
                guard (0...1).contains(eta), right[i] > left[i] else { throw StaticMeasurementError.invalid("轮廓层面应位于头顶至足底间且右边界大于左边界") }
                curve.append(StaticCurvePoint(x: eta, y: (right[i] - left[i]) / h))
            }
            curve.sort { $0.x < $1.x }
            result = StaticMeasurementResult(values: [value("layerCount", "已记录层面数", Double(curve.count), "层")], curve: curve, notes: ["曲线 x 为从头顶向下的空间相对高度 η，y 为宽度/像素身高；不是时间曲线。不插补遮挡或缺失层面。"])
        case .sr01, .sr02:
            let leftX = v[feature == .sr01 ? "leftX" : "leftEarX"]!, rightX = v[feature == .sr01 ? "rightX" : "rightEarX"]!
            let leftY = v[feature == .sr01 ? "leftY" : "leftEarY"]!, rightY = v[feature == .sr01 ? "rightY" : "rightEarY"]!
            guard leftX != rightX || leftY != rightY else { throw StaticMeasurementError.invalid("左右点不能重合") }
            let delta = rightY - leftY
            var values = [value(feature == .sr01 ? "shoulderAngleDegrees" : "headAngleDegrees", feature == .sr01 ? "肩部外轮廓角" : "耳垂线倾斜角", atan2(delta, abs(rightX - leftX)) * 180 / .pi, "°")]
            if feature == .sr01, let scale = try pointScale() { values.append(value("shoulderHeightDifferenceCM", "身体右肩 − 左肩高差", scale * delta, "cm")) }
            result = StaticMeasurementResult(values: values, notes: ["坐标 y 向上；正值表示身体右侧点更高，负值表示左侧更高。保留镜像与身体左右说明。外观差异不等于病变或损伤风险。"])
        case .sr03:
            guard v["upperRightX"]! > v["upperLeftX"]!, v["waistRightX"]! > v["waistLeftX"]!, v["upperY"]! > v["waistY"]! else { throw StaticMeasurementError.invalid("左右轮廓顺序或腋下/肚脐层面顺序") }
            let upper = (v["upperLeftX"]! + v["upperRightX"]!) / 2
            let waist = (v["waistLeftX"]! + v["waistRightX"]!) / 2
            let delta = upper - waist
            var values = [value("outlineOffsetPixels", "上层轮廓中点 − 腰部中点", delta, "px"), value("outlineAngleDegrees", "轮廓中线偏移角", atan2(delta, abs(v["upperY"]! - v["waistY"]!)) * 180 / .pi, "°")]
            if let scale = try pointScale() { values.append(value("outlineOffsetCM", "轮廓中点横向偏移", scale * delta, "cm")) }
            result = StaticMeasurementResult(values: values, notes: ["坐标 x 向右、y 向上；正值表示画面上层中点偏右，负值偏左。轮廓中线不是脊柱或重心。"])
        case .sr04:
            let left = input.series["leftGirthsCM"]!, right = input.series["rightGirthsCM"]!
            guard (2...3).contains(left.count), (2...3).contains(right.count) else { throw StaticMeasurementError.invalid("每侧需要 2–3 次同层面独立围度测量") }
            let l = left.reduce(0, +) / Double(left.count), r = right.reduce(0, +) / Double(right.count)
            result = StaticMeasurementResult(values: [value("leftMeanCM", "左侧围度均值", l, "cm"), value("rightMeanCM", "右侧围度均值", r, "cm"), value("girthDifferenceCM", "左 − 右围度差", l - r, "cm"), value("girthAsymmetryPercent", "双侧均值作分母的差异", 100 * abs(l - r) / ((l + r) / 2), "%")], notes: ["围度差不等于力量或肌肉质量差；不套 10%/15% 伤病阈值。"])
        case .sr05:
            let count = v["eventCount"]!
            guard count > 0 || input.dates.isEmpty else { throw StaticMeasurementError.invalid("零事件次数不能附最近事件/恢复日期") }
            if let last = input.dates["lastEventDate"], let returned = input.dates["returnToSportDate"], returned < last { throw StaticMeasurementError.invalid("恢复运动日期早于最近事件日期") }
            var values = [value("eventCount", "该部位既往事件次数", count, "次")]
            for (key, output, title) in [("lastEventDate", "daysSinceLastEvent", "距最近事件"), ("returnToSportDate", "daysSinceReturnToSport", "距恢复运动")] {
                if let date = input.dates[key] {
                    guard date <= now else { throw StaticMeasurementError.invalid("事件/恢复日期不能晚于当前日期") }
                    values.append(value(output, title, now.timeIntervalSince(date) / 86_400, "天"))
                }
            }
            result = StaticMeasurementResult(values: values, notes: ["本人背景记录；未知日期保持缺失。经过天数以 24 小时为一天。自报疑似事件不自动升级为诊断，不生成风险分。"])
        case .sr06:
            result = StaticMeasurementResult(values: [value("restingNRS", "现在静息疼痛 NRS", v["restingNRS"]!, "分")], notes: ["0 不痛，10 可想象最严重疼痛；这是当前主观症状，不是未来受伤概率。"])
        case .h01:
            let a = v["widthCM"]! / 2, b = v["depthCM"]! / 2
            let intervals = 8192
            let step = 2 * Double.pi / Double(intervals)
            func integrand(_ t: Double) -> Double { hypot(a * sin(t), b * cos(t)) }
            var sum = integrand(0) + integrand(2 * .pi)
            for i in 1..<intervals { sum += Double(i.isMultiple(of: 2) ? 2 : 4) * integrand(Double(i) * step) }
            result = StaticMeasurementResult(values: [value("ellipseEstimatedGirthCM", "椭圆模型估计围度", sum * step / 3, "cm")], notes: ["采用椭圆假设与 Simpson 数值积分；该估计不等同软尺实测围度，不用于推断肌肉量。"])
        case .h02:
            let components = input.targets
            guard !components.isEmpty, Set(components.map(\.id)).count == components.count,
                  Set(components.map(\.metricKey)).count == components.count else { throw StaticMeasurementError.invalid("目标列表为空或存在重复项目") }
            let allowed = Set(StaticFeatureCatalog.targetMetrics.map(\.id))
            var squaredDistance = 0.0
            var differences: [StaticResultValue] = []
            for component in components {
                guard allowed.contains(component.metricKey), !component.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      [component.observed, component.lowerBound, component.upperBound, component.scale, component.weight].allSatisfy(\.isFinite),
                      component.observed > 0, component.lowerBound >= 0, component.upperBound >= component.lowerBound,
                      component.scale > 0, component.weight >= 0 else { throw StaticMeasurementError.invalid("目标原始比例、区间、尺度或权重") }
                let distance = max(max(component.lowerBound - component.observed, 0), component.observed - component.upperBound) / component.scale
                guard distance.isFinite else { throw StaticMeasurementError.nonFiniteResult }
                if component.weight > 0 { squaredDistance += component.weight * distance * distance }
                differences.append(value("targetDifference:\(component.id)", "\(component.title)标准化偏离", distance, ""))
            }
            guard abs(components.reduce(0) { $0 + $1.weight } - 1) <= 0.000000001 else { throw StaticMeasurementError.invalid("所选权重之和必须为 1") }
            guard squaredDistance.isFinite else { throw StaticMeasurementError.nonFiniteResult }
            result = StaticMeasurementResult(values: [value("targetMatch", "与自设目标的匹配度", 100 * exp(-0.5 * squaredDistance), "%")] + differences, notes: ["全部所选项目均已提供原始比例、目标区间、尺度和权重；参数改变会改变分数。这是个人目标接近程度，不是客观美丑、天赋或训练收益。"])
        case .h03: throw StaticMeasurementError.referenceLibraryUnavailable
        case .q02:
            let repeats = input.series["repeats"]!
            guard repeats.count >= 3 else { throw StaticMeasurementError.invalid("至少三次独立重测") }
            let isAngle = context("measurementType", input) == "角度"
            guard isAngle || repeats.allSatisfy({ $0 > 0 }) else { throw StaticMeasurementError.invalid("物理长度重测必须为正；有符号差值不按长度计算 CV") }
            let count = Double(repeats.count), mean = repeats.reduce(0, +) / count
            let variance = repeats.reduce(0) { $0 + pow($1 - mean, 2) } / (count - 1)
            let sd = sqrt(variance), unit = isAngle ? "°" : "cm"
            var values = [value("repeatCount", "独立重测次数", count, "次"), value("mean", "均值", mean, unit), value("sampleSD", "样本标准差", sd, unit), value("minimum", "最小值", repeats.min()!, unit), value("maximum", "最大值", repeats.max()!, unit), value("range", "范围跨度", repeats.max()! - repeats.min()!, unit)]
            if unit == "cm", mean > 0 { values.append(value("cvPercent", "变异系数 CV", 100 * sd / mean, "%")) }
            result = StaticMeasurementResult(values: values, notes: ["标准差分母为 n−1；仅均值为正的长度报告 CV，角度不报告 CV。重复稳定不代表准确，必须独立重拍而非复制一个数值。"])
        }
        guard result.values.allSatisfy({ $0.value.isFinite }), result.curve?.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) ?? true else { throw StaticMeasurementError.nonFiniteResult }
        return result
    }

    private static func context(_ key: String, _ input: StaticMeasurementInput) -> String? { input.text[key] ?? input.metadata[key] }

    private static func validate(feature: StaticFeatureID, input: StaticMeasurementInput) throws {
        let fields = StaticFeatureCatalog.inputFields(for: feature)
        guard Set(input.values.keys).isSubset(of: Set(fields.filter { $0.kind == .number }.map(\.key))),
              Set(input.series.keys).isSubset(of: Set(fields.filter { $0.kind == .series }.map(\.key))),
              Set(input.dates.keys).isSubset(of: Set(fields.filter { $0.kind == .date }.map(\.key))),
              feature == .h02 || input.targets.isEmpty else { throw StaticMeasurementError.unexpectedFields }
        for field in fields {
            switch field.kind {
            case .number:
                guard let number = input.values[field.key] else { if field.required { throw StaticMeasurementError.missing(field.title) }; continue }
                guard number.isFinite, field.range?.contains(number) ?? true, !field.isInteger || number.rounded() == number else { throw StaticMeasurementError.invalid(field.title) }
            case .series:
                guard let series = input.series[field.key] else { if field.required { throw StaticMeasurementError.missing(field.title) }; continue }
                guard !series.isEmpty, series.count <= 10000, series.allSatisfy({ $0.isFinite && (field.range?.contains($0) ?? true) }) else { throw StaticMeasurementError.invalid(field.title) }
            case .text:
                guard let text = context(field.key, input) else { if field.required { throw StaticMeasurementError.missing(field.title) }; continue }
                guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      field.options.isEmpty || field.options.contains(text) else { throw StaticMeasurementError.invalid(field.title) }
            case .date:
                guard let date = input.dates[field.key] else { if field.required { throw StaticMeasurementError.missing(field.title) }; continue }
                guard date.timeIntervalSince1970.isFinite else { throw StaticMeasurementError.invalid(field.title) }
            }
        }
        // Acquisition text and metadata are deliberately extensible and never enter numeric formulas.
    }
}
