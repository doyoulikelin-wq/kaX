import SwiftUI

/// Records dimensions already measured by the user. No camera-derived values are fabricated.
struct RankingMeasurementForm: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMetric: RankingMetric
    @State private var textValues: [String: String] = [:]
    @State private var saveError: String?
    @FocusState private var focusedField: String?
    private let allowsMetricSelection: Bool

    init(metric: RankingMetric, allowsMetricSelection: Bool = false) {
        _selectedMetric = State(initialValue: metric)
        self.allowsMetricSelection = allowsMetricSelection
    }

    private var enteredValues: [String: Double]? {
        var values: [String: Double] = [:]
        for field in selectedMetric.inputFields {
            let text = (textValues[field.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard let number = Double(text), number.isFinite else { return nil }
            values[field.id] = number
        }
        guard (try? selectedMetric.calculatedValue(from: values)) != nil else { return nil }
        return values
    }

    private var result: Double? {
        enteredValues.flatMap { try? selectedMetric.calculatedValue(from: $0) }
    }

    private var validationMessage: String? {
        for field in selectedMetric.inputFields {
            let text = (textValues[field.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            guard let value = Double(text), value.isFinite, field.allowedRange.contains(value),
                  !field.isInteger || value.rounded() == value else {
                return "请核对\(field.title)的数值和单位。"
            }
        }
        if selectedMetric.inputFields.allSatisfy({ !(textValues[$0.id] ?? "").isEmpty }), enteredValues == nil {
            return "请核对测量值之间的关系，例如坐高应小于身高。"
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                if allowsMetricSelection {
                    Section("选择指标") {
                        Picker("记录项目", selection: $selectedMetric) {
                            ForEach(RankingCategory.allCases) { category in
                                Section(category.title) {
                                    ForEach(RankingMetric.allCases.filter { $0.category == category }) { metric in
                                        Text(metric.title).tag(metric)
                                    }
                                }
                            }
                        }.accessibilityIdentifier("measurementMetricPicker")
                    }
                }
                Section {
                    Text(selectedMetric.measurementGuide)
                        .font(.subheadline)
                    Text("本次填写已测得的尺寸。照片自动提取尚未接入。")
                        .font(.footnote).foregroundStyle(.secondary)
                } header: { Text("测量口径") }

                Section {
                    ForEach(selectedMetric.inputFields) { field in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(field.title).font(.subheadline)
                            HStack {
                                TextField("填写本次测量", text: Binding(
                                    get: { textValues[field.id] ?? "" },
                                    set: { textValues[field.id] = $0 }
                                ))
                                .keyboardType(field.isInteger ? .numberPad : .decimalPad)
                                .focused($focusedField, equals: field.id)
                                .accessibilityLabel(field.title)
                                .accessibilityIdentifier("rankingInput-\(field.id)")
                                Text(field.unit).foregroundStyle(.secondary)
                            }
                        }.padding(.vertical, 3)
                    }
                    if let validationMessage {
                        Text(validationMessage).font(.footnote).foregroundStyle(.red)
                            .accessibilityIdentifier("rankingValidationMessage")
                    }
                } header: { Text("原始测量") }
                footer: { Text("填写本次实测值，统一使用厘米。所有输入会与结果一起保存。") }

                Section {
                    Text(selectedMetric.formula).font(.subheadline)
                    if let result {
                        HStack {
                            Text("本次结果")
                            Spacer()
                            Text("\(selectedMetric.formattedValue(result)) \(selectedMetric.unit)")
                                .font(.title3.weight(.semibold)).monospacedDigit()
                                .accessibilityIdentifier("rankingCalculatedValue")
                        }
                    } else {
                        Text("填写完整后计算结果")
                            .foregroundStyle(.secondary)
                    }
                    Text(selectedMetric.interpretation)
                        .font(.footnote).foregroundStyle(.secondary)
                } header: { Text("计算预览") }

                Section {
                    OriginBadge(origin: .manual)
                    Text("保存后作为该测量口径的最新记录参与示例比较。排序描述数值位置，不代表身体优劣。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle(selectedMetric.title)
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .disabled(enteredValues == nil)
                        .accessibilityIdentifier("saveRankingMeasurementButton")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { focusedField = nil }
                        .accessibilityIdentifier("keyboardDoneButton")
                }
            }
            .onChange(of: selectedMetric) { _, _ in
                focusedField = nil
                textValues = [:]
            }
            .alert("记录未能保存", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
                Button("知道了") { saveError = nil }
            } message: { Text(saveError ?? "") }
        }
    }

    private func save() {
        focusedField = nil
        guard let values = enteredValues else { return }
        store.saveRankingMeasurement(RankingMeasurement(personID: store.profile.id, metric: selectedMetric, values: values, origin: .manual))
        if let error = store.persistenceError { saveError = error } else { dismiss() }
    }
}
