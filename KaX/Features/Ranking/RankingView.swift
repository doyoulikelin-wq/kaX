import SwiftUI

struct RankingView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var category: RankingCategory = .structure
    @State private var metric: RankingMetric = .armSpanRatio
    @State private var scope: RankingScope = .all
    @State private var activeSheet: RankingSheet?

    private enum RankingScope: String, CaseIterable, Identifiable {
        case all = "全部"
        case friends = "关注"
        var id: String { rawValue }
    }

    private enum RankingSheet: Identifiable {
        case measurement(RankingMetric)
        case evidence(RankingMetric)
        case entry(RankingMetric, EvidenceRankEntry)

        var id: String {
            switch self {
            case .measurement(let metric): return "measurement-\(metric.id)"
            case .evidence(let metric): return "evidence-\(metric.id)"
            case .entry(let metric, let entry): return "entry-\(metric.id)-\(entry.id)"
            }
        }
    }

    private var availableMetrics: [RankingMetric] {
        RankingMetric.allCases.filter { $0.category == category }
    }

    private var entries: [EvidenceRankEntry] {
        store.rankingEntries(for: metric, followingOnly: scope == .friends)
    }

    private var ownEntry: EvidenceRankEntry? {
        entries.first(where: \.isCurrentUser)
    }

    private var requiredInputs: String {
        metric.inputFields.map(\.title).joined(separator: "、")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("每一项，都有测量依据")
                            .font(.title3.weight(.semibold))
                        Text("尺寸比例与当前形体，分别记录。")
                            .font(.subheadline)
                            .foregroundStyle(KaXTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Picker("数据类别", selection: $category) {
                        ForEach(RankingCategory.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("rankingCategoryPicker")

                    HStack(alignment: .center, spacing: 12) {
                        Menu {
                            ForEach(availableMetrics) { item in
                                Button {
                                    metric = item
                                } label: {
                                    HStack {
                                        Text(item.title)
                                        if item == metric {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                                .accessibilityIdentifier("selectMetric-\(item.rawValue)")
                            }
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(metric.title)
                                    .font(.title3.weight(.semibold))
                                    .fixedSize(horizontal: false, vertical: true)
                                Image(systemName: "chevron.down")
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(KaXTheme.ink)
                            .frame(minHeight: 44, alignment: .leading)
                        }
                        .accessibilityLabel("选择排行指标，当前\(metric.title)")
                        .accessibilityIdentifier("rankingMetricPicker")
                        Spacer(minLength: 0)
                        Button {
                            activeSheet = .evidence(metric)
                        } label: {
                            Image(systemName: "info.circle")
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .accessibilityLabel("查看\(metric.title)的指标依据")
                        .accessibilityIdentifier("leaderboardInfoButton")
                    }

                    Picker("榜单范围", selection: $scope) {
                        ForEach(RankingScope.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("leaderboardFilterPicker")

                    ownMeasurementCard

                    VStack(alignment: .leading, spacing: 12) {
                        ViewThatFits(in: .horizontal) {
                            HStack {
                                sampleHeading.fixedSize()
                                Spacer(minLength: 12)
                                sampleCount.fixedSize()
                            }
                            VStack(alignment: .leading, spacing: 5) {
                                sampleHeading
                                sampleCount
                            }
                        }
                        Text("采用每人同口径的最新记录，校验合格后入榜。")
                            .font(.caption)
                            .foregroundStyle(KaXTheme.muted)
                        if entries.isEmpty {
                            EmptyStateView(
                                symbol: "ruler",
                                title: "本项还没有数据",
                                message: "记录\(requiredInputs)，即可查看你在本机样本中的位置。"
                            )
                            .padding(.vertical, 12)
                        } else {
                            ForEach(entries) { entry in
                                rankingRow(entry)
                            }
                        }
                    }

                    Text("按本项数值从高到低排列。排位只表示本机样本中的静态数据位置，不代表优劣、综合天赋或真实人群百分位。")
                        .font(.caption)
                        .foregroundStyle(KaXTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)
                        .padding(.bottom, 12)
                }
                .padding(20)
                .pageWidth()
            }
            .background(KaXTheme.background)
            .navigationTitle("数据排行")
            .onChange(of: category) { _, newCategory in
                if metric.category != newCategory,
                   let firstMetric = RankingMetric.allCases.first(where: { $0.category == newCategory }) {
                    metric = firstMetric
                }
            }
            .sheet(item: $activeSheet) { sheet in
                Group {
                    switch sheet {
                    case .measurement(let selectedMetric):
                        RankingMeasurementForm(metric: selectedMetric)
                    case .evidence(let selectedMetric):
                        RankingEvidenceView(metric: selectedMetric)
                    case .entry(let selectedMetric, let entry):
                        RankingEntryDetailView(metric: selectedMetric, entry: entry)
                    }
                }
                .environment(store)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .accessibilityIdentifier("leaderboardScreen")
        }
    }

    private var ownMeasurementCard: some View {
        RoundedPanel {
            VStack(alignment: .leading, spacing: 18) {
                if let entry = ownEntry {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .center, spacing: 16) {
                            currentMetric(entry).fixedSize()
                            Spacer(minLength: 10)
                            currentPosition(entry).fixedSize()
                        }
                        VStack(alignment: .leading, spacing: 16) {
                            currentMetric(entry)
                            currentPosition(entry)
                        }
                    }
                    OriginBadge(origin: entry.measurement.origin)
                } else {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("我的\(metric.title)")
                            .font(.caption)
                            .foregroundStyle(KaXTheme.muted)
                        Text("待记录").font(.title2.weight(.semibold))
                        Text("需要记录：\(requiredInputs)。")
                            .font(.footnote)
                            .foregroundStyle(KaXTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("同一次、同一测量口径的数据，才能放进本项比较。")
                            .font(.caption)
                            .foregroundStyle(KaXTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Button {
                    activeSheet = .measurement(metric)
                } label: {
                    Text(ownEntry == nil ? "记录这项" : "重新测量")
                        .font(.subheadline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("recordRankingMeasurementButton")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("currentUserRank")
    }

    private var sampleHeading: some View {
        HStack(spacing: 6) {
            Circle().fill(KaXTheme.accent).frame(width: 5, height: 5)
            Text("本机示例榜").font(.headline)
        }
    }

    private var sampleCount: some View {
        Text("\(entries.count) 人样本")
            .font(.caption)
            .foregroundStyle(KaXTheme.muted)
    }

    private func rankingRow(_ entry: EvidenceRankEntry) -> some View {
        Button {
            activeSheet = .entry(metric, entry)
        } label: {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 12) {
                        rankPerson(entry)
                        rankValue(entry)
                            .padding(.leading, 36)
                    }
                } else {
                    HStack(spacing: 12) {
                        rankPerson(entry)
                        Spacer(minLength: 5)
                        rankValue(entry).fixedSize()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(KaXTheme.muted)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(entry.isCurrentUser ? KaXTheme.accent.opacity(0.07) : KaXTheme.card, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(entry.isCurrentUser ? KaXTheme.accent.opacity(0.25) : KaXTheme.line, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("第\(entry.position)名，\(entry.name)\(entry.isCurrentUser ? "，我" : "")，\(metric.title)\(metric.formattedValue(entry.value))\(metric.unit)，\(entry.measurement.origin.title)，查看原始测量")
        .accessibilityIdentifier("rankEntry-\(entry.id)")
    }

    private func rankPerson(_ entry: EvidenceRankEntry) -> some View {
        HStack(spacing: 12) {
            Text("\(entry.position)")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(entry.isCurrentUser ? KaXTheme.accent : KaXTheme.muted)
                .frame(minWidth: 24)
            AvatarView(initials: entry.initials)
            VStack(alignment: .leading, spacing: 5) {
                Text(entry.isCurrentUser ? "\(entry.name) · 我" : entry.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(KaXTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                OriginBadge(origin: entry.measurement.origin)
            }
        }
    }

    private func rankValue(_ entry: EvidenceRankEntry) -> some View {
        Text("\(metric.formattedValue(entry.value)) \(metric.unit)")
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(entry.isCurrentUser ? KaXTheme.accent : KaXTheme.ink)
    }

    private func currentMetric(_ entry: EvidenceRankEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("我的\(metric.title)").font(.caption).foregroundStyle(KaXTheme.muted)
            MetricValue(value: metric.formattedValue(entry.value), unit: metric.unit)
        }
    }

    private func currentPosition(_ entry: EvidenceRankEntry) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("第 \(entry.position) 名")
                .font(.title3.weight(.semibold))
                .foregroundStyle(KaXTheme.accent)
            Text("\(entries.count) 人本机样本")
                .font(.caption)
                .foregroundStyle(KaXTheme.muted)
        }
    }
}
