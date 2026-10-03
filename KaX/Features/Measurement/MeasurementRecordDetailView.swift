import SwiftUI

struct MeasurementRecordDetailView: View {
    let record: MeasurementRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text(record.kind.title)
                        .font(.title2.bold())
                    Spacer()
                    OriginBadge(origin: record.origin)
                }

                RoundedPanel {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(record.title)
                            .font(.subheadline)
                            .foregroundStyle(KaXTheme.muted)
                        MetricValue(value: MeasurementFormatting.recordValue(record), unit: record.unit)
                        if let value = record.secondaryValue {
                            HStack {
                                Text(secondaryTitle)
                                    .foregroundStyle(KaXTheme.muted)
                                Spacer()
                                Text("\(MeasurementFormatting.number(value)) \(secondaryUnit)")
                                    .monospacedDigit()
                            }
                            .font(.subheadline)
                        }
                        Divider().overlay(KaXTheme.line)
                        Text(record.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.footnote)
                            .foregroundStyle(KaXTheme.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !record.note.isEmpty {
                    RoundedPanel {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("记录详情")
                                .font(.headline)
                            Text(record.note)
                                .font(.subheadline)
                                .foregroundStyle(KaXTheme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Text(sourceDescription)
                    .font(.footnote)
                    .foregroundStyle(KaXTheme.muted)
            }
            .padding(20)
        }
        .background(KaXTheme.background)
        .foregroundStyle(KaXTheme.ink)
        .navigationTitle("测量记录")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .accessibilityIdentifier("measurementRecordDetailScreen")
    }

    private var secondaryTitle: String {
        switch record.kind {
        case .body: "身高"
        case .strength: "完成次数"
        case .emg: "采集时长"
        }
    }

    private var secondaryUnit: String {
        switch record.kind {
        case .body: "cm"
        case .strength: "次"
        case .emg: "秒"
        }
    }

    private var sourceDescription: String {
        switch record.origin {
        case .manual: "数据来源：手动录入。"
        case .demo: "数据来源：模拟信号，用于展示采集流程。"
        case .device: "数据来源：设备测量。"
        }
    }
}
