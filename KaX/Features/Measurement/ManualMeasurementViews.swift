import SwiftUI

struct BodyMeasurementFormView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var height = ""
    @State private var weight = ""
    @State private var armSpan = ""
    @State private var waist = ""
    @State private var didLoadProfile = false
    @FocusState private var focusedField: MeasurementInput?

    private var values: (height: Double, weight: Double, armSpan: Double, waist: Double)? {
        guard let heightValue = MeasurementFormatting.validNumber(height, in: 50...260),
              let weightValue = MeasurementFormatting.validNumber(weight, in: 20...500),
              let armSpanValue = MeasurementFormatting.validNumber(armSpan, in: 50...300),
              let waistValue = MeasurementFormatting.validNumber(waist, in: 30...300) else {
            return nil
        }
        return (heightValue, weightValue, armSpanValue, waistValue)
    }

    private var validationMessage: String {
        let fields: [(String, String, ClosedRange<Double>)] = [
            (height, "身高需要在 50–260 cm 之间。", 50...260),
            (weight, "体重需要在 20–500 kg 之间。", 20...500),
            (armSpan, "臂展需要在 50–300 cm 之间。", 50...300),
            (waist, "腰围需要在 30–300 cm 之间。", 30...300)
        ]
        for (text, message, range) in fields where !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if MeasurementFormatting.validNumber(text, in: range) == nil { return message }
        }
        return values == nil ? "填写全部四项后可保存。" : "手动录入 · 保存后同步到身体档案。"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text("身体记录")
                            .font(.title2.bold())
                        Spacer()
                        OriginBadge(origin: .manual)
                    }

                    RoundedPanel {
                        VStack(spacing: 18) {
                            MeasurementInputField(title: "身高", unit: "cm", text: $height, identifier: "bodyHeightField", focus: $focusedField, field: .height)
                            Divider().overlay(KaXTheme.line)
                            MeasurementInputField(title: "体重", unit: "kg", text: $weight, identifier: "bodyWeightField", focus: $focusedField, field: .bodyWeight)
                            Divider().overlay(KaXTheme.line)
                            MeasurementInputField(title: "臂展", unit: "cm", text: $armSpan, identifier: "bodyArmSpanField", focus: $focusedField, field: .armSpan)
                            Divider().overlay(KaXTheme.line)
                            MeasurementInputField(title: "腰围", unit: "cm", text: $waist, identifier: "bodyWaistField", focus: $focusedField, field: .waist)
                        }
                    }

                    Text(validationMessage)
                        .font(.footnote)
                        .foregroundStyle(KaXTheme.muted)
                        .accessibilityIdentifier("bodyValidationMessage")

                    if let values {
                        RoundedPanel {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("臂展 / 身高")
                                        .font(.subheadline)
                                        .foregroundStyle(KaXTheme.muted)
                                    Text(String(format: "%.3f", values.armSpan / values.height))
                                        .font(.title.weight(.semibold))
                                        .monospacedDigit()
                                }
                                Spacer()
                                Image(systemName: "figure.arms.open")
                                    .font(.largeTitle)
                                    .foregroundStyle(KaXTheme.accent)
                            }
                        }
                    }

                    MeasurementSaveButton(title: "保存记录", isEnabled: values != nil) {
                        saveMeasurement()
                    }
                    .accessibilityIdentifier("saveMeasurementButton")

                    if let message = store.persistenceError {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(KaXTheme.muted)
                    }
                }
                .padding(20)
            }
            .background(KaXTheme.background)
            .foregroundStyle(KaXTheme.ink)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("身体")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        focusedField = nil
                        dismiss()
                    }
                        .foregroundStyle(KaXTheme.ink)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { focusedField = nil }
                        .foregroundStyle(KaXTheme.ink)
                        .accessibilityIdentifier("keyboardDoneButton")
                }
            }
            .onAppear {
                guard !didLoadProfile else { return }
                didLoadProfile = true
                guard let latest = store.latestBody, latest.origin != .demo else { return }
                height = MeasurementFormatting.number(store.profile.heightCM)
                weight = MeasurementFormatting.number(store.profile.weightKG)
                armSpan = MeasurementFormatting.number(store.profile.armSpanCM)
                waist = MeasurementFormatting.number(store.profile.waistCM)
            }
        }
        .accessibilityIdentifier("bodyMeasurementScreen")
    }

    private func saveMeasurement() {
        focusedField = nil
        guard let values else { return }
        var updatedProfile = store.profile
        updatedProfile.heightCM = values.height
        updatedProfile.weightKG = values.weight
        updatedProfile.armSpanCM = values.armSpan
        updatedProfile.waistCM = values.waist
        let note = "身高 \(MeasurementFormatting.number(values.height)) cm · 体重 \(MeasurementFormatting.number(values.weight)) kg · 腰围 \(MeasurementFormatting.number(values.waist)) cm"
        let record = MeasurementRecord(
            id: UUID(),
            date: Date(),
            kind: .body,
            title: "臂展",
            value: values.armSpan,
            unit: "cm",
            secondaryValue: values.height,
            origin: .manual,
            note: note
        )
        store.recordBody(profile: updatedProfile, record: record)
        if store.persistenceError == nil { dismiss() }
    }
}

struct StrengthMeasurementFormView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var weight = ""
    @State private var repetitions = ""
    @FocusState private var focusedField: MeasurementInput?

    private var values: (weight: Double, repetitions: Int)? {
        guard let weightValue = MeasurementFormatting.validNumber(weight, in: 1...1000),
              let repetitionsValue = Int(repetitions.trimmingCharacters(in: .whitespacesAndNewlines)),
              (1...30).contains(repetitionsValue) else {
            return nil
        }
        return (weightValue, repetitionsValue)
    }

    private var validationMessage: String {
        if !weight.isEmpty, MeasurementFormatting.validNumber(weight, in: 1...1000) == nil {
            return "重量需要在 1–1000 kg 之间。"
        }
        if !repetitions.isEmpty {
            guard let count = Int(repetitions.trimmingCharacters(in: .whitespacesAndNewlines)), (1...30).contains(count) else {
                return "次数需要是 1–30 之间的整数。"
            }
        }
        return values == nil ? "填写重量与次数后可保存。" : "记录这组实际完成的重量与次数。"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("卧推")
                                .font(.title2.bold())
                            Text("工作组记录")
                                .font(.subheadline)
                                .foregroundStyle(KaXTheme.muted)
                        }
                        Spacer()
                        OriginBadge(origin: .manual)
                    }

                    RoundedPanel {
                        VStack(spacing: 18) {
                            MeasurementInputField(title: "重量", unit: "kg", text: $weight, identifier: "strengthWeightField", focus: $focusedField, field: .strengthWeight)
                            Divider().overlay(KaXTheme.line)
                            MeasurementInputField(title: "次数", unit: "次", text: $repetitions, identifier: "strengthRepsField", focus: $focusedField, field: .repetitions, keyboard: .numberPad)
                        }
                    }

                    Text(validationMessage)
                        .font(.footnote)
                        .foregroundStyle(KaXTheme.muted)
                        .accessibilityIdentifier("strengthValidationMessage")

                    if let values {
                        RoundedPanel {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                MetricValue(value: MeasurementFormatting.number(values.weight), unit: "kg")
                                Text("× \(values.repetitions) 次")
                                    .font(.title3)
                                    .foregroundStyle(KaXTheme.muted)
                                Spacer(minLength: 0)
                            }
                        }
                    }

                    MeasurementSaveButton(title: "保存记录", isEnabled: values != nil) {
                        saveMeasurement()
                    }
                    .accessibilityIdentifier("saveMeasurementButton")

                    if let message = store.persistenceError {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(KaXTheme.muted)
                    }
                }
                .padding(20)
            }
            .background(KaXTheme.background)
            .foregroundStyle(KaXTheme.ink)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("力量")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        focusedField = nil
                        dismiss()
                    }
                        .foregroundStyle(KaXTheme.ink)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { focusedField = nil }
                        .foregroundStyle(KaXTheme.ink)
                        .accessibilityIdentifier("keyboardDoneButton")
                }
            }
        }
        .accessibilityIdentifier("strengthMeasurementScreen")
    }

    private func saveMeasurement() {
        focusedField = nil
        guard let values else { return }
        let record = MeasurementRecord(
            id: UUID(),
            date: Date(),
            kind: .strength,
            title: "卧推",
            value: values.weight,
            unit: "kg",
            secondaryValue: Double(values.repetitions),
            origin: .manual,
            note: "工作组 · \(MeasurementFormatting.number(values.weight)) kg × \(values.repetitions) 次"
        )
        store.addRecord(record)
        if store.persistenceError == nil { dismiss() }
    }
}

private struct MeasurementInputField: View {
    let title: String
    let unit: String
    @Binding var text: String
    let identifier: String
    var focus: FocusState<MeasurementInput?>.Binding
    let field: MeasurementInput
    var keyboard: UIKeyboardType = .decimalPad

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .frame(width: 48, alignment: .leading)
            TextField("请输入", text: $text)
                .focused(focus, equals: field)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .multilineTextAlignment(.trailing)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .accessibilityLabel(title)
                .accessibilityIdentifier(identifier)
            Text(unit)
                .font(.subheadline)
                .foregroundStyle(KaXTheme.muted)
                .frame(width: 24, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }
}

private enum MeasurementInput: Hashable {
    case height, bodyWeight, armSpan, waist, strengthWeight, repetitions
}

struct MeasurementSaveButton: View {
    let title: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .foregroundStyle(.white)
                .background(KaXTheme.accent, in: RoundedRectangle(cornerRadius: 17))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }
}

enum MeasurementFormatting {
    static func number(_ value: Double, precision: Int = 1) -> String {
        guard value.isFinite else { return "—" }
        return value.formatted(.number.precision(.fractionLength(0...precision)).grouping(.never))
    }

    static func recordValue(_ record: MeasurementRecord) -> String {
        number(record.value, precision: record.kind == .emg ? 3 : 1)
    }

    static func validNumber(_ text: String, in range: ClosedRange<Double>) -> Double? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value.isFinite, range.contains(value) else { return nil }
        return value
    }
}
