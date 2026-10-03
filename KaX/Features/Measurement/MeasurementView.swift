import SwiftUI

struct MeasurementView: View {
    @Environment(AppStore.self) private var store
    @State private var presentedSheet: MeasurementSheet?

    private var recentRecords: [MeasurementRecord] {
        store.records.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("测量")
                            .font(.largeTitle.bold())
                            .foregroundStyle(KaXTheme.ink)
                        Text("记录身体，也记录每一次变化。")
                            .font(.subheadline)
                            .foregroundStyle(KaXTheme.muted)
                    }

                    Button {
                        presentedSheet = .device
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "waveform")
                                .font(.title3)
                                .foregroundStyle(KaXTheme.accent)
                                .frame(width: 38, height: 38)
                                .background(KaXTheme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("EMG 卡片")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(KaXTheme.ink)
                                Text("未连接")
                                    .font(.caption)
                                    .foregroundStyle(KaXTheme.muted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(KaXTheme.muted)
                        }
                        .padding(16)
                        .background(KaXTheme.card, in: RoundedRectangle(cornerRadius: 20))
                        .overlay {
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(KaXTheme.line, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("deviceButton")

                    VStack(spacing: 12) {
                        measurementCard(
                            title: "身体",
                            subtitle: "身高 · 体重 · 臂展 · 腰围",
                            symbol: MeasurementKind.body.systemImage,
                            record: store.latestBody,
                            emptyValue: "建立身体记录",
                            identifier: "bodyMeasurementButton"
                        ) { presentedSheet = .body }

                        measurementCard(
                            title: "力量",
                            subtitle: "卧推工作重量与次数",
                            symbol: MeasurementKind.strength.systemImage,
                            record: store.latestStrength,
                            emptyValue: "记录一次卧推",
                            identifier: "strengthMeasurementButton"
                        ) { presentedSheet = .strength }

                        measurementCard(
                            title: "肌电",
                            subtitle: "未连接设备 · 可查看采集演示",
                            symbol: MeasurementKind.emg.systemImage,
                            record: store.latestEMG,
                            emptyValue: "体验采集演示",
                            identifier: "emgMeasurementButton"
                        ) { presentedSheet = .emg }
                    }

                    Button { presentedSheet = .ranking } label: {
                        RoundedPanel {
                            HStack(spacing: 14) {
                                Image(systemName: "ruler").font(.title2).foregroundStyle(KaXTheme.accent)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("静态比例测量").font(.headline)
                                    Text("臂展、坐高、轮廓宽度、手足与围度比例")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").font(.caption)
                            }
                        }
                    }.buttonStyle(.plain).accessibilityIdentifier("staticRankingMeasurementButton")

                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeading(title: "最近记录", subtitle: "每条记录都保留数据来源")
                        if recentRecords.isEmpty {
                            RoundedPanel {
                                EmptyStateView(
                                    symbol: "chart.xyaxis.line",
                                    title: "还没有测量记录",
                                    message: "从身体、力量或肌电演示开始。"
                                )
                            }
                        } else {
                            ForEach(recentRecords) { record in
                                NavigationLink {
                                    MeasurementRecordDetailView(record: record)
                                } label: {
                                    recordRow(record)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("measurementRecord_\(record.id.uuidString)")
                            }
                        }
                    }

                    if let message = store.persistenceError {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(KaXTheme.muted)
                            .accessibilityIdentifier("measurementPersistenceError")
                    }
                }
                .padding(20)
            }
            .background(KaXTheme.background)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $presentedSheet) { sheet in
                switch sheet {
                case .body:
                    BodyMeasurementFormView()
                case .strength:
                    StrengthMeasurementFormView()
                case .emg:
                    EMGMeasurementView()
                case .device:
                    MeasurementDeviceView()
                case .ranking:
                    RankingMeasurementForm(metric: .armSpanRatio, allowsMetricSelection: true)
                }
            }
        }
        .accessibilityIdentifier("measurementScreen")
    }

    private func measurementCard(
        title: String,
        subtitle: String,
        symbol: String,
        record: MeasurementRecord?,
        emptyValue: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            RoundedPanel {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) {
                        Image(systemName: symbol)
                            .foregroundStyle(KaXTheme.accent)
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(KaXTheme.ink)
                        Spacer()
                        Image(systemName: "plus")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(KaXTheme.muted)
                    }

                    if let record {
                        if record.kind == .body || record.kind == .emg {
                            Text(record.kind == .body ? record.title : "幅度摘要")
                                .font(.caption)
                                .foregroundStyle(KaXTheme.muted)
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            MetricValue(value: MeasurementFormatting.recordValue(record), unit: record.unit)
                            if record.kind == .strength, let repetitions = record.secondaryValue {
                                Text("× \(MeasurementFormatting.number(repetitions)) 次")
                                    .font(.subheadline)
                                    .foregroundStyle(KaXTheme.muted)
                            }
                            Spacer(minLength: 0)
                        }
                        HStack {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(KaXTheme.muted)
                            Spacer(minLength: 4)
                            OriginBadge(origin: record.origin)
                        }
                    } else {
                        Text(emptyValue)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(KaXTheme.ink)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(KaXTheme.muted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    private func recordRow(_ record: MeasurementRecord) -> some View {
        RoundedPanel {
            HStack(spacing: 12) {
                Image(systemName: record.kind.systemImage)
                    .foregroundStyle(KaXTheme.accent)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 6) {
                    Text(record.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(KaXTheme.ink)
                    HStack(spacing: 8) {
                        Text(record.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(KaXTheme.muted)
                        OriginBadge(origin: record.origin)
                    }
                }
                Spacer(minLength: 8)
                Text("\(MeasurementFormatting.recordValue(record)) \(record.unit)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(KaXTheme.ink)
                    .monospacedDigit()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(KaXTheme.muted)
            }
        }
    }
}

private enum MeasurementSheet: String, Identifiable {
    case body, strength, emg, device, ranking
    var id: String { rawValue }
}

private struct MeasurementDeviceView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "waveform")
                        .font(.system(size: 54, weight: .light))
                        .foregroundStyle(KaXTheme.accent)
                        .frame(height: 120)

                    RoundedPanel {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("EMG 卡片")
                                    .font(.title3.weight(.semibold))
                                Spacer()
                                Text("未连接")
                                    .font(.subheadline)
                                    .foregroundStyle(KaXTheme.muted)
                                    .accessibilityIdentifier("deviceConnectionStatus")
                            }
                            Text("当前没有连接真实设备。你可以从肌电入口查看采集演示。")
                                .font(.subheadline)
                                .foregroundStyle(KaXTheme.muted)
                            Text("演示记录会单独标记，保留清楚的数据来源。")
                                .font(.footnote)
                                .foregroundStyle(KaXTheme.muted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(20)
            }
            .background(KaXTheme.background)
            .foregroundStyle(KaXTheme.ink)
            .navigationTitle("设备")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(KaXTheme.ink)
                }
            }
        }
        .accessibilityIdentifier("measurementDeviceScreen")
    }
}
