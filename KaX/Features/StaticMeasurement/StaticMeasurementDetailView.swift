import SwiftUI
import Charts

struct StaticFeatureDetailView: View {
    @Environment(AppStore.self) private var store
    let feature: StaticFeatureMetadata
    @State private var showsForm = false

    private var records: [StaticMeasurementRecord] {
        store.staticMeasurements.filter { $0.feature == feature.id }
            .sorted { $0.date == $1.date ? $0.id.uuidString < $1.id.uuidString : $0.date > $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(feature.id.rawValue) · \(feature.group)")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(feature.title).font(.title2.bold())
                        .fixedSize(horizontal: false, vertical: true)
                }

                if feature.availability == .requiresReferenceLibrary {
                    RoundedPanel {
                        Label("参考库尚未接入", systemImage: "books.vertical")
                            .font(.headline)
                        Text("可以查看所需数据与计算方法。目前没有真实参考样本，不生成百分位或人群名次。")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                } else {
                    Button("录入并计算") { showsForm = true }
                        .buttonStyle(KaXPrimaryButtonStyle())
                        .accessibilityIdentifier("recordStaticMeasurementButton")
                }

                NavigationLink {
                    StaticMeasurementHistoryView(featureID: feature.id)
                } label: {
                    Label("本项记录（\(records.count)）", systemImage: "clock.arrow.circlepath")
                }
                .accessibilityIdentifier("staticFeatureHistoryButton")

                ForEach(Array(records.prefix(2))) { record in
                    NavigationLink {
                        StaticMeasurementRecordDetailView(record: record)
                    } label: { StaticMeasurementHistoryRow(record: record) }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("staticRecord-\(record.id.uuidString)")
                }

                StaticFeatureEvidenceContent(feature: feature)
            }
            .padding(20).pageWidth()
        }
        .background(KaXTheme.background)
        .navigationTitle(feature.id.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("staticFeatureDetailScreen")
        .sheet(isPresented: $showsForm) {
            StaticMeasurementFormView(feature: feature).environment(store)
        }
    }
}

struct StaticFeatureEvidenceContent: View {
    let feature: StaticFeatureMetadata

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            evidencePanel("原始数据", text: feature.data)
            evidencePanel("采集方法", text: feature.measurementGuide)
            RoundedPanel {
                VStack(alignment: .leading, spacing: 10) {
                    Text("公式").font(.headline)
                    Text(feature.formula).font(.subheadline)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("staticFeatureFormula")
                }
            }
            evidencePanel("用途", text: feature.interpretation)
            evidencePanel("适用边界", text: feature.limitations)
            if !feature.talentInference.isEmpty { evidencePanel("能否解释天赋", text: feature.talentInference) }
            if !feature.evidence.isEmpty { evidencePanel("证据现状", text: feature.evidence) }
            if !feature.validation.isEmpty { evidencePanel("验证方法", text: feature.validation) }
            if !feature.route.isEmpty || !feature.mode.isEmpty || !feature.formulaType.isEmpty {
                RoundedPanel {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("采集路径").font(.headline)
                        if !feature.route.isEmpty { Text(feature.route) }
                        if !feature.mode.isEmpty { Text(feature.mode) }
                        if !feature.formulaType.isEmpty { Text(feature.formulaType) }
                    }
                    .font(.footnote).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            if ["SM08", "SM09"].contains(feature.id.rawValue) {
                evidencePanel("投影与点位确认", text: "照片关键点必须人工确认。这里计算的是指定照片平面的投影估计；自动模型与镜头畸变校正是否接入，以采集页面的实际状态为准。")
            }
            if ["SR05", "SR06"].contains(feature.id.rawValue) {
                evidencePanel("个人背景", text: "这项信息仅保存在本机，作为本人的背景记录，不进入身体或天赋排名。")
            }
            if feature.id.rawValue == "H02" {
                evidencePanel("由你定义匹配目标", text: "区间、尺度和权重都由你自行设置。结果描述数据与这套目标的匹配程度，不提供预设黄金比例，也不代表客观身体优劣。")
            }
            if feature.id.rawValue == "Q02" {
                evidencePanel("重复测量", text: "保留每次样本值，查看均值、标准差和范围。变异系数只用于长度测量，不用于把角度误差转换成比例。")
            }
            RoundedPanel {
                VStack(alignment: .leading, spacing: 12) {
                    Text("来源与口径").font(.headline)
                    ForEach(feature.sourceReferences, id: \.id) { source in
                        VStack(alignment: .leading, spacing: 5) {
                            Text("\(source.id) · \(source.title)").font(.subheadline.weight(.medium))
                            Text(source.reportSection).font(.caption).foregroundStyle(.secondary)
                            if !source.evidence.isEmpty { Text(source.evidence).font(.caption).foregroundStyle(.secondary) }
                            if !source.limitations.isEmpty { Text(source.limitations).font(.caption).foregroundStyle(.secondary) }
                            if !source.access.isEmpty { Text(source.access).font(.caption).foregroundStyle(.secondary) }
                            if let urlString = source.url, let url = URL(string: urlString) {
                                Link("查看来源", destination: url).font(.caption.weight(.medium))
                            }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("staticSource-\(source.id)")
                    }
                    Text("口径：\(feature.protocolID)")
                        .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                }
            }
        }
    }

    private func evidencePanel(_ title: String, text: String) -> some View {
        RoundedPanel {
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct StaticMeasurementResultView: View {
    let result: StaticMeasurementResult
    var featureID: StaticFeatureID? = nil
    var input: StaticMeasurementInput? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            RoundedPanel {
                VStack(alignment: .leading, spacing: 16) {
                    Text("计算结果").font(.headline)
                    ForEach(result.values, id: \.id) { value in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(value.title).font(.subheadline).foregroundStyle(.secondary)
                            Text("\(StaticMeasurementFormatting.number(value.value)) \(value.unit)")
                                .font(.title2.weight(.semibold)).monospacedDigit()
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("staticResult-\(value.id)")
                        }
                    }
                    ForEach(Array(result.notes.enumerated()), id: \.offset) { _, note in
                        Text(note).font(.footnote).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if let curve = result.curve, !curve.isEmpty {
                RoundedPanel {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("轮廓曲线").font(.headline)
                        Chart(Array(curve.enumerated()), id: \.offset) { _, point in
                            LineMark(x: .value("相对高度", point.x), y: .value("宽度", point.y))
                                .foregroundStyle(KaXTheme.accent)
                            PointMark(x: .value("相对高度", point.x), y: .value("宽度", point.y))
                                .foregroundStyle(KaXTheme.accent)
                        }
                        .frame(height: 220)
                        .chartXAxisLabel("相对高度")
                        .chartYAxisLabel("宽度 / 像素身高")
                        .accessibilityLabel("根据已录入样本生成的轮廓曲线")
                        .accessibilityIdentifier("staticContourChart")
                    }
                }
            }
            if featureID?.rawValue == "Q02", let input {
                RoundedPanel {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("重复测量样本").font(.headline)
                        ForEach(input.series.keys.sorted(), id: \.self) { key in
                            ForEach(Array((input.series[key] ?? []).enumerated()), id: \.offset) { index, value in
                                Text("第 \(index + 1) 次：\(StaticMeasurementFormatting.number(value))")
                                    .font(.subheadline).monospacedDigit()
                            }
                        }
                    }
                }
            }
        }
    }
}

struct StaticMeasurementRecordDetailView: View {
    let record: StaticMeasurementRecord
    private var feature: StaticFeatureMetadata? { StaticFeatureCatalog.metadata(for: record.feature) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(feature?.title ?? record.feature.rawValue).font(.title2.bold())
                    Text(record.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline).foregroundStyle(.secondary)
                    OriginBadge(origin: record.origin)
                }
                StaticMeasurementResultView(result: record.result, featureID: record.feature, input: record.input)
                if let imageID = record.input.text["imageID"] ?? record.input.metadata["imageID"],
                   let image = StaticPhotoFiles.image(for: imageID) {
                    RoundedPanel {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("本次采集照片").font(.headline)
                            Image(uiImage: image).resizable().scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .accessibilityLabel("保存在本机的本次采集照片")
                                .accessibilityIdentifier("staticRecordedPhoto")
                        }
                    }
                }
                StaticRecordedInputView(input: record.input, feature: feature)
                if let feature { StaticFeatureEvidenceContent(feature: feature) }
            }
            .padding(20).pageWidth()
        }
        .background(KaXTheme.background)
        .navigationTitle("测量详情")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("staticMeasurementRecordDetailScreen")
    }
}

struct StaticRecordedInputView: View {
    let input: StaticMeasurementInput
    let feature: StaticFeatureMetadata?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            RoundedPanel {
                VStack(alignment: .leading, spacing: 12) {
                    Text("原始输入").font(.headline)
                    ForEach(feature?.inputFields ?? [], id: \.id) { field in
                        if let summary = inputSummary(field) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(field.title).font(.caption).foregroundStyle(.secondary)
                                Text(summary).font(.subheadline).monospacedDigit().textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("staticRecordedInput-\(field.key)")
                        }
                    }
                    ForEach(input.targets, id: \.id) { target in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(target.title).font(.subheadline.weight(.semibold))
                            Text("观测值 \(StaticMeasurementFormatting.number(target.observed))；目标区间 \(StaticMeasurementFormatting.number(target.lowerBound))–\(StaticMeasurementFormatting.number(target.upperBound))")
                            Text("尺度 \(StaticMeasurementFormatting.number(target.scale))；权重 \(StaticMeasurementFormatting.number(target.weight))")
                        }
                        .font(.caption).fixedSize(horizontal: false, vertical: true)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("staticRecordedTarget-\(target.id)")
                    }
                }
            }
            let context = input.metadata.merging(input.text) { _, new in new }
            if context["inputMode"] == "photo" {
                StaticPhotoContextView(text: context)
            }
        }
    }

    private func inputSummary(_ field: StaticInputField) -> String? {
        switch field.kind {
        case .number:
            guard let value = input.values[field.key] else { return nil }
            return "\(StaticMeasurementFormatting.number(value)) \(field.unit)"
        case .series:
            guard let values = input.series[field.key], !values.isEmpty else { return nil }
            return values.map(StaticMeasurementFormatting.number).joined(separator: "、") + " \(field.unit)"
        case .text:
            guard let value = input.text[field.key] ?? input.metadata[field.key], !value.isEmpty else { return nil }
            return value
        case .date:
            guard let value = input.dates[field.key] else { return nil }
            return value.formatted(date: .abbreviated, time: .omitted)
        }
    }
}

struct StaticPhotoContextView: View {
    let text: [String: String]

    var body: some View {
        RoundedPanel {
            VStack(alignment: .leading, spacing: 8) {
                Text("照片采集信息").font(.headline)
                if let source = text["pointSource"] { Text("点位：\(source)") }
                if let width = text["imageWidth"], let height = text["imageHeight"] { Text("图片尺寸：\(width) × \(height) 像素") }
                if let method = text["calibrationMethod"] { Text("尺度与校正：\(method)") }
                if let plane = text["samePlaneConfirmed"] { Text("同平面条件：\(confirmationLabel(plane))") }
                if let level = text["levelConfirmed"] { Text("水平条件：\(confirmationLabel(level))") }
                Text("原照片用于溯源；计算以保存的原始输入为准。")
            }
            .font(.footnote).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier("staticPhotoContext")
    }

    private func confirmationLabel(_ value: String) -> String {
        switch value.lowercased() {
        case "true", "yes", "1": return "本人已确认"
        case "false", "no", "0": return "尚未确认"
        default: return value
        }
    }
}
