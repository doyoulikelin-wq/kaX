import SwiftUI

struct RankingEvidenceView: View {
    @Environment(\.dismiss) private var dismiss
    let metric: RankingMetric

    var body: some View {
        NavigationStack {
            RankingEvidenceContent(metric: metric)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") { dismiss() }
                            .accessibilityIdentifier("closeRankingEvidenceButton")
                    }
                }
        }
    }
}

private struct RankingEvidenceContent: View {
    let metric: RankingMetric

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(metric.title).font(.title2.weight(.semibold))
                    Text(metric.category.title)
                        .font(.subheadline)
                        .foregroundStyle(KaXTheme.muted)
                }

                evidencePanel("计算口径", text: metric.formula, identifier: "rankingFormula")
                evidencePanel("测量方法", text: metric.measurementGuide)
                evidencePanel("数值的含义", text: metric.interpretation)
                evidencePanel("适用边界", text: metric.limitations)
                evidencePanel(
                    "产品排序选择",
                    text: "按本项显示到两位小数的比值从高到低排列，显示值相同使用相同名次。这个排列方向是产品的展示选择，只表示本机样本中的数据位置，不表示身体优劣、综合天赋或真实人群百分位。"
                )

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeading(title: "来源与报告位置")
                    ForEach(metric.sourceReferences) { source in
                        RoundedPanel {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(source.id)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(KaXTheme.accent)
                                    .accessibilityIdentifier("rankingSource-\(source.id)")
                                Text(source.title)
                                    .font(.subheadline.weight(.semibold))
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(source.reportSection)
                                    .font(.footnote)
                                    .foregroundStyle(KaXTheme.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .textSelection(.enabled)
                                if let sourceURL = source.sourceURL, let url = URL(string: sourceURL) {
                                    Link(destination: url) {
                                        Label("查看原始来源", systemImage: "arrow.up.right")
                                            .font(.subheadline)
                                            .frame(minHeight: 44)
                                    }
                                    .accessibilityIdentifier("rankingSourceLink-\(source.id)")
                                } else {
                                    Text("依据为报告中的测量定义或产品口径，未附外部研究链接。")
                                        .font(.caption)
                                        .foregroundStyle(KaXTheme.muted)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
                .accessibilityIdentifier("rankingSources")

                VStack(alignment: .leading, spacing: 6) {
                    Text("测量口径标识")
                        .font(.caption)
                        .foregroundStyle(KaXTheme.muted)
                    Text(metric.protocolID)
                        .font(.caption.monospaced())
                        .foregroundStyle(KaXTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
            .padding(20)
            .pageWidth()
        }
        .background(KaXTheme.background)
        .navigationTitle("指标依据")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("rankingEvidenceScreen")
    }

    private func evidencePanel(_ title: String, text: String, identifier: String? = nil) -> some View {
        RoundedPanel {
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(.headline)
                if let identifier {
                    Text(text)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                        .accessibilityIdentifier(identifier)
                } else {
                    Text(text)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
        }
    }
}

struct RankingEntryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let metric: RankingMetric
    let entry: EvidenceRankEntry

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    RoundedPanel {
                        VStack(alignment: .leading, spacing: 18) {
                            HStack(spacing: 12) {
                                AvatarView(initials: entry.initials, size: 48)
                                Text(entry.name)
                                    .font(.title3.weight(.semibold))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Text(metric.title).font(.subheadline).foregroundStyle(KaXTheme.muted)
                                MetricValue(value: metric.formattedValue(entry.value), unit: metric.unit)
                            }
                            OriginBadge(origin: entry.measurement.origin)
                            if entry.measurement.origin == .demo {
                                Text("这是一条演示数据，用于展示本机比较流程。")
                                    .font(.caption)
                                    .foregroundStyle(KaXTheme.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    RoundedPanel {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("原始测量").font(.headline)
                            ForEach(metric.inputFields) { field in
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(field.title).font(.caption).foregroundStyle(KaXTheme.muted)
                                    if let value = entry.measurement.values[field.id] {
                                        Text("\(value.formatted(.number.precision(.fractionLength(0...3)))) \(field.unit)")
                                            .font(.body.weight(.medium))
                                            .monospacedDigit()
                                            .fixedSize(horizontal: false, vertical: true)
                                    } else {
                                        Text("未记录").font(.body).foregroundStyle(KaXTheme.muted)
                                    }
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityIdentifier("rankingInput-\(field.id)")
                            }
                            Divider()
                            VStack(alignment: .leading, spacing: 6) {
                                Text("记录日期").font(.caption).foregroundStyle(KaXTheme.muted)
                                Text(entry.measurement.date, format: .dateTime.year().month().day().hour().minute())
                                    .font(.subheadline)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                Text("测量口径").font(.caption).foregroundStyle(KaXTheme.muted)
                                Text(entry.measurement.protocolID)
                                    .font(.caption.monospaced())
                                    .fixedSize(horizontal: false, vertical: true)
                                    .textSelection(.enabled)
                            }
                            Text("本榜采用每人每项同口径最新记录，校验合格后入榜。")
                                .font(.caption)
                                .foregroundStyle(KaXTheme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    RoundedPanel {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("计算公式").font(.headline)
                            Text(metric.formula)
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                                .accessibilityIdentifier("rankingFormula")
                            Text(metric.interpretation)
                                .font(.footnote)
                                .foregroundStyle(KaXTheme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                            NavigationLink {
                                RankingEvidenceContent(metric: metric)
                            } label: {
                                Label("查看指标依据", systemImage: "doc.text.magnifyingglass")
                                    .font(.subheadline)
                                    .frame(minHeight: 44)
                            }
                            .accessibilityIdentifier("entryEvidenceButton")
                        }
                    }
                }
                .padding(20)
                .pageWidth()
            }
            .background(KaXTheme.background)
            .navigationTitle("测量详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .accessibilityIdentifier("rankingEntryDetailScreen")
        }
    }
}
