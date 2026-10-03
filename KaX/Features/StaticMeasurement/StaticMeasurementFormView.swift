import SwiftUI

struct StaticMeasurementFormView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let feature: StaticFeatureMetadata
    @State private var numberText: [String: String] = [:]
    @State private var seriesText: [String: String] = [:]
    @State private var textValues: [String: String] = ["inputMode": "manual"]
    @State private var dateValues: [String: Date] = [:]
    @State private var acquisitionMetadata: [String: String] = [:]
    @State private var targets: [StaticTargetDraft] = []
    @State private var measuredAt = Date()
    @State private var preview: StaticMeasurementResult?
    @State private var errorMessage: String?
    @State private var showsPhotoTool = false
    @State private var useRankingProtocol = false

    private var supportsPhotoTool: Bool {
        ["SM01", "Q01", "SM08", "SM09", "SR01", "SR02", "SR03"].contains(feature.id.rawValue)
    }

    private var photoContext: [String: String] {
        acquisitionMetadata.merging(textValues) { _, new in new }
    }

    private var compatibleRankings: [RankingMetric] {
        switch feature.id {
        case .sm02: return [.armSpanRatio]
        case .sm03: return [.relativeShoulderWidth]
        case .sm04: return [.shoulderWaistWidthRatio, .waistHipWidthRatio]
        case .sm07: return [.legBodyRatio]
        case .sm10: return [.handAspectRatio]
        case .sm11: return [.footAspectRatio]
        case .sm12: return [.waistHipGirthRatio]
        default: return []
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(feature.title).font(.title2.bold())
                            .fixedSize(horizontal: false, vertical: true)
                        Text("录入本次原始数据；计算后可保存在本机。")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }

                    if feature.availability == .requiresReferenceLibrary {
                        EmptyStateView(symbol: "books.vertical", title: "参考库尚未接入", message: "没有真实参考样本，当前不生成百分位。请返回查看方法与所需数据。")
                    } else {
                        if supportsPhotoTool {
                            Button { showsPhotoTool = true } label: {
                                Label("从照片标点", systemImage: "photo.badge.plus")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity).padding(14)
                                    .background(KaXTheme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                            }
                            .accessibilityIdentifier("staticPhotoMeasurementButton")
                        }

                        if photoContext["inputMode"] == "photo" {
                            StaticPhotoContextView(text: photoContext)
                        }

                        if ["SM08", "SM09"].contains(feature.id.rawValue) {
                            Text("请人工确认点位、侧别与同平面尺度。结果是照片投影估计，不等于内部骨长。")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        if ["SR05", "SR06"].contains(feature.id.rawValue) {
                            Text("个人背景仅保存在本机，不进入排名。")
                                .font(.footnote).foregroundStyle(.secondary)
                        }

                        if feature.id == .h02 {
                            targetInputs
                        }

                        if !feature.inputFields.isEmpty {
                            RoundedPanel {
                                VStack(alignment: .leading, spacing: 20) {
                                    Text("原始输入").font(.headline)
                                    ForEach(feature.inputFields) { field in
                                        inputField(field)
                                    }
                                }
                            }
                        }

                        if !compatibleRankings.isEmpty {
                            RoundedPanel {
                                VStack(alignment: .leading, spacing: 12) {
                                    Toggle("同时用于对应比例榜", isOn: $useRankingProtocol)
                                        .disabled(photoContext["inputMode"] == "photo")
                                        .accessibilityIdentifier("staticRankingProtocolToggle")
                                    if photoContext["inputMode"] == "photo" {
                                        Text("照片投影结果保留在测量库，不进入手工比例榜。")
                                            .font(.caption).foregroundStyle(.secondary)
                                    } else if useRankingProtocol {
                                        Text("启用即确认已按下面固定口径测量，并按对应榜单范围校验。校验不通过时，请关闭开关以单独保存到测量库。")
                                            .font(.caption).foregroundStyle(.secondary)
                                        ForEach(compatibleRankings) { metric in
                                            VStack(alignment: .leading, spacing: 5) {
                                                Text(metric.title).font(.subheadline.weight(.semibold))
                                                Text(metric.measurementGuide).font(.footnote).foregroundStyle(.secondary)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                        }
                                    } else {
                                        Text("默认仅保存到测量库。需要参加比例榜时，再确认对应测量口径。")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }

                        RoundedPanel {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("测量时间").font(.headline)
                                DatePicker("时间", selection: $measuredAt, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                                    .labelsHidden()
                                    .accessibilityLabel("测量时间")
                                    .accessibilityIdentifier("staticMeasurementDatePicker")
                                Text("本次来源：本人录入。原始数据与采集信息会一起保存。")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }

                        DisclosureGroup("查看采集方法与公式") {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(feature.measurementGuide)
                                Text(feature.formula).textSelection(.enabled)
                            }
                            .font(.footnote).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true).padding(.top, 10)
                        }

                        Button("计算预览") { calculatePreview() }
                            .font(.headline).frame(maxWidth: .infinity).padding(14)
                            .background(KaXTheme.card, in: RoundedRectangle(cornerRadius: 14))
                            .accessibilityIdentifier("calculateStaticMeasurementButton")

                        if let preview {
                            StaticMeasurementResultView(result: preview, featureID: feature.id, input: try? makeInput())
                        }

                        if let errorMessage {
                            Text(errorMessage).font(.footnote).foregroundStyle(.red)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("staticMeasurementError")
                        }

                        Button("计算并保存") { save() }
                            .buttonStyle(KaXPrimaryButtonStyle())
                            .accessibilityIdentifier("saveStaticMeasurementButton")
                    }
                }
                .padding(20).pageWidth()
            }
            .background(KaXTheme.background)
            .navigationTitle(feature.id.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() }.accessibilityIdentifier("cancelStaticMeasurementButton") }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完成") { hideKeyboard() }.accessibilityIdentifier("keyboardDoneButton") }
            }
            .onChange(of: targets) { _, _ in preview = nil; errorMessage = nil }
            .onChange(of: measuredAt) { _, _ in preview = nil; errorMessage = nil }
            .onChange(of: useRankingProtocol) { _, _ in invalidatePreview() }
        }
        .accessibilityIdentifier("staticMeasurementFormScreen")
        .sheet(isPresented: $showsPhotoTool) {
            StaticPhotoMeasurementView(feature: feature.id) { input in
                applyPhotoInput(input)
            }
        }
    }

    @ViewBuilder
    private func inputField(_ field: StaticInputField) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(field.title + (field.optional ? "（选填）" : ""))
                .font(.subheadline.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
            switch field.kind {
            case .number:
                ViewThatFits(in: .horizontal) {
                    HStack { numericTextField(field); Text(field.unit).foregroundStyle(.secondary) }
                    VStack(alignment: .leading, spacing: 5) { numericTextField(field); Text(field.unit).foregroundStyle(.secondary) }
                }
                if let range = field.range {
                    Text("范围 \(StaticMeasurementFormatting.number(range.lowerBound))–\(StaticMeasurementFormatting.number(range.upperBound)) \(field.unit)" + (field.isInteger ? " · 整数" : ""))
                        .font(.caption).foregroundStyle(.secondary)
                }
            case .series:
                TextField("用逗号或空格分隔", text: seriesBinding(field.key), axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .accessibilityIdentifier("staticInput-\(field.key)")
                Text(field.unit.isEmpty ? "保留每次测量值，按原顺序输入。" : "单位：\(field.unit)；保留每次测量值，按原顺序输入。")
                    .font(.caption).foregroundStyle(.secondary)
            case .text:
                if field.key == "calibrationStatus", photoContext["inputMode"] == "photo" {
                    Text(photoContext["calibrationStatus"] ?? "仅像素")
                        .font(.subheadline.weight(.medium))
                        .accessibilityIdentifier("staticInput-\(field.key)")
                    Text("照片的尺度条件由标点工具确认。需要调整时，请重新进入“从照片标点”。")
                        .font(.caption).foregroundStyle(.secondary)
                } else if field.options.isEmpty {
                    TextField("填写\(field.title)", text: textBinding(field.key), axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("staticInput-\(field.key)")
                } else {
                    Picker(field.title, selection: textBinding(field.key)) {
                        Text("请选择").tag("")
                        ForEach(field.options, id: \.self) { option in Text(option).tag(option) }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("staticInput-\(field.key)")
                }
            case .date:
                if field.optional {
                    Toggle("填写这项日期", isOn: Binding(get: { dateValues[field.key] != nil }, set: { enabled in
                        dateValues[field.key] = enabled ? Date() : nil
                        preview = nil; errorMessage = nil
                    }))
                    .font(.subheadline)
                    .accessibilityIdentifier("staticDateEnabled-\(field.key)")
                }
                if !field.optional || dateValues[field.key] != nil {
                    DatePicker(field.title, selection: Binding(get: { dateValues[field.key] ?? Date() }, set: { value in
                        dateValues[field.key] = value; preview = nil; errorMessage = nil
                    }), displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .accessibilityIdentifier("staticInput-\(field.key)")
                }
            }
        }
    }

    private func numericTextField(_ field: StaticInputField) -> some View {
        TextField("输入\(field.title)", text: numberBinding(field.key))
            .textFieldStyle(.roundedBorder)
            .keyboardType((field.range?.lowerBound ?? 0) < 0 ? .numbersAndPunctuation : .decimalPad)
            .accessibilityIdentifier("staticInput-\(field.key)")
    }

    private var targetInputs: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("设置自己的目标区间").font(.headline)
            Text("逐项选择已测比例，再填写观测值、目标区间、尺度和权重。全部权重之和须为 1。没有预设黄金值；这只是与你的目标比较。")
                .font(.footnote).foregroundStyle(.secondary)
            ForEach($targets) { $target in
                StaticTargetEditor(draft: $target) {
                    targets.removeAll { $0.id == target.id }
                }
            }
            Button {
                targets.append(StaticTargetDraft(metricKey: StaticFeatureCatalog.targetMetrics.first?.id ?? ""))
            } label: { Label("添加一个目标", systemImage: "plus.circle") }
            .accessibilityIdentifier("addStaticTargetButton")
        }
    }

    private func numberBinding(_ key: String) -> Binding<String> {
        Binding(get: { numberText[key] ?? "" }, set: { value in
            guard value != (numberText[key] ?? "") else { return }
            numberText[key] = value; didEditPhotoValues(); invalidatePreview()
        })
    }
    private func seriesBinding(_ key: String) -> Binding<String> {
        Binding(get: { seriesText[key] ?? "" }, set: { value in
            guard value != (seriesText[key] ?? "") else { return }
            seriesText[key] = value; didEditPhotoValues(); invalidatePreview()
        })
    }
    private func textBinding(_ key: String) -> Binding<String> {
        Binding(get: { textValues[key] ?? acquisitionMetadata[key] ?? "" }, set: { value in
            guard value != (textValues[key] ?? acquisitionMetadata[key] ?? "") else { return }
            textValues[key] = value
            didEditPhotoValues(); invalidatePreview()
        })
    }
    private func invalidatePreview() { preview = nil; errorMessage = nil }

    private func didEditPhotoValues() {
        if photoContext["inputMode"] == "photo" {
            textValues["pointSource"] = "人工修正"
            textValues.removeValue(forKey: "photoPointsJSON")
            acquisitionMetadata.removeValue(forKey: "photoPointsJSON")
            if acquisitionMetadata["pointSource"] != nil { acquisitionMetadata["pointSource"] = "人工修正" }
        }
    }

    private func applyPhotoInput(_ input: StaticMeasurementInput) {
        numberText = input.values.mapValues { String($0) }
        seriesText = input.series.mapValues { $0.map { String($0) }.joined(separator: ", ") }
        textValues = input.text
        dateValues = input.dates
        acquisitionMetadata = input.metadata
        textValues["inputMode"] = "photo"
        useRankingProtocol = false
        invalidatePreview()
        showsPhotoTool = false
    }

    private func makeInput() throws -> StaticMeasurementInput {
        var values: [String: Double] = [:]
        var series: [String: [Double]] = [:]
        var text = textValues
        if useRankingProtocol && photoContext["inputMode"] != "photo" && !compatibleRankings.isEmpty {
            text["rankingProtocolConfirmed"] = "true"
        } else {
            text.removeValue(forKey: "rankingProtocolConfirmed")
        }
        var dates = dateValues
        for field in feature.inputFields {
            switch field.kind {
            case .number:
                let raw = (numberText[field.key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if raw.isEmpty, field.optional { continue }
                values[field.key] = try parseNumber(raw, title: field.title)
            case .series:
                let raw = (seriesText[field.key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if raw.isEmpty, field.optional { continue }
                let parts = raw.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",，;；"))).filter { !$0.isEmpty }
                guard !parts.isEmpty else { throw StaticFormError.message("请填写\(field.title)。") }
                series[field.key] = try parts.map { try parseNumber($0, title: field.title) }
            case .text:
                let raw = (text[field.key] ?? acquisitionMetadata[field.key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if raw.isEmpty, !field.optional { throw StaticFormError.message("请填写\(field.title)。") }
                if raw.isEmpty { text.removeValue(forKey: field.key) } else { text[field.key] = raw }
            case .date:
                if dates[field.key] == nil, !field.optional { dates[field.key] = Date() }
            }
        }
        let components = try targets.map { target -> StaticTargetComponent in
            guard let metric = StaticFeatureCatalog.targetMetrics.first(where: { $0.id == target.metricKey }) else {
                throw StaticFormError.message("请选择目标对应的比例。")
            }
            return StaticTargetComponent(id: target.id, title: metric.title, metricKey: metric.id,
                                         observed: try parseNumber(target.observed, title: "\(metric.title)观测值"),
                                         lowerBound: try parseNumber(target.lower, title: "\(metric.title)目标下限"),
                                         upperBound: try parseNumber(target.upper, title: "\(metric.title)目标上限"),
                                         scale: try parseNumber(target.scale, title: "\(metric.title)尺度"),
                                         weight: try parseNumber(target.weight, title: "\(metric.title)权重"))
        }
        return StaticMeasurementInput(values: values, series: series, text: text, dates: dates, targets: components, metadata: acquisitionMetadata)
    }

    private func parseNumber(_ raw: String, title: String) throws -> Double {
        guard let value = Double(raw.trimmingCharacters(in: .whitespacesAndNewlines)), value.isFinite else {
            throw StaticFormError.message("请为\(title)填写有效数字。")
        }
        return value
    }

    private func calculatePreview() {
        hideKeyboard()
        do {
            preview = try StaticMeasurementCalculator.calculate(feature: feature.id, input: makeInput(), now: measuredAt)
            errorMessage = nil
        } catch { preview = nil; errorMessage = error.localizedDescription }
    }

    private func save() {
        hideKeyboard()
        do {
            let input = try makeInput()
            let result = try StaticMeasurementCalculator.calculate(feature: feature.id, input: input, now: measuredAt)
            let record = StaticMeasurementRecord(date: measuredAt, feature: feature.id, input: input, result: result, origin: .manual)
            store.saveStaticMeasurement(record)
            guard store.staticMeasurements.contains(where: { $0.id == record.id }) else {
                errorMessage = store.persistenceError ?? "测量未保存，请重试。"
                return
            }
            dismiss()
        } catch { preview = nil; errorMessage = error.localizedDescription }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

private enum StaticFormError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let value) = self { value } else { nil } }
}

private struct StaticTargetDraft: Identifiable, Equatable {
    var id = UUID().uuidString
    var metricKey: String
    var observed = ""
    var lower = ""
    var upper = ""
    var scale = ""
    var weight = ""
}

private struct StaticTargetEditor: View {
    @Binding var draft: StaticTargetDraft
    let remove: () -> Void

    var body: some View {
        RoundedPanel {
            VStack(alignment: .leading, spacing: 14) {
                Picker("目标比例", selection: $draft.metricKey) {
                    ForEach(StaticFeatureCatalog.targetMetrics) { metric in Text(metric.title).tag(metric.id) }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("staticTargetMetric-\(draft.id)")
                targetField("观测比值", text: $draft.observed, key: "observed")
                targetField("目标下限", text: $draft.lower, key: "lower")
                targetField("目标上限", text: $draft.upper, key: "upper")
                targetField("尺度（大于 0）", text: $draft.scale, key: "scale")
                targetField("权重（不小于 0）", text: $draft.weight, key: "weight")
                Button("移除这项目标", role: .destructive, action: remove)
                    .font(.caption)
                    .accessibilityIdentifier("removeStaticTarget-\(draft.id)")
            }
        }
    }

    private func targetField(_ title: String, text: Binding<String>, key: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline)
            TextField(title, text: text).textFieldStyle(.roundedBorder).keyboardType(.decimalPad)
                .accessibilityIdentifier("staticTarget-\(key)-\(draft.id)")
        }
    }
}
