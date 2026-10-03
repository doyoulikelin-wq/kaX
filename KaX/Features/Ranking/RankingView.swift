import SwiftUI

struct RankingView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var scope: RankingScope = .all
    @State private var showsRules = false

    private enum RankingScope: String, CaseIterable, Identifiable {
        case all = "全部"
        case friends = "关注"
        var id: String { rawValue }
    }

    private var entries: [RankEntry] {
        let followingIDs = Set(store.people.filter(\.isFollowing).map(\.id))
        return store.leaderboard.filter { entry in
            entry.value > 0 && (scope == .all || entry.isCurrentUser || followingIDs.contains(entry.id))
        }
    }

    private var myRank: Int? {
        entries.firstIndex(where: \.isCurrentUser).map { $0 + 1 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 7) {
                            Circle().fill(KaXTheme.accent).frame(width: 5, height: 5)
                            Text("示例榜单")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(KaXTheme.muted)
                        }
                        Text("看看你的力量，\n在小圈子里的位置。")
                            .font(.title2.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(alignment: .top, spacing: 12) {
                            if dynamicTypeSize.isAccessibilitySize {
                                VStack(alignment: .leading, spacing: 6) {
                                    Label("卧推", systemImage: "dumbbell")
                                    Text("体重比").foregroundStyle(KaXTheme.muted)
                                }
                            } else {
                                Label("卧推", systemImage: "dumbbell")
                                Text("·").foregroundStyle(KaXTheme.muted)
                                Text("体重比").foregroundStyle(KaXTheme.muted)
                            }
                            Spacer(minLength: 0)
                            rulesButton
                        }
                        .font(.subheadline.weight(.medium))
                    }

                    Picker("榜单范围", selection: $scope) {
                        ForEach(RankingScope.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("leaderboardFilterPicker")

                    if let mine = entries.first(where: \.isCurrentUser), let myRank {
                        RoundedPanel {
                            ViewThatFits(in: .horizontal) {
                                HStack(alignment: .center, spacing: 16) {
                                    currentMetric(mine).fixedSize()
                                    Spacer(minLength: 10)
                                    currentPosition(myRank).fixedSize()
                                }
                                VStack(alignment: .leading, spacing: 18) {
                                    currentMetric(mine)
                                    currentPosition(myRank)
                                }
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("currentUserRank")
                    } else {
                        RoundedPanel {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("我的卧推体重比").font(.caption).foregroundStyle(KaXTheme.muted)
                                Text("待记录").font(.title2.weight(.semibold))
                                Text("先在测量页录入自己的身体数据（含体重）和卧推力量记录，再参与排名。")
                                    .font(.footnote)
                                    .foregroundStyle(KaXTheme.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeading(title: scope == .all ? "卧推榜" : "关注的人 · 卧推榜", trailing: "\(entries.count) 人")
                        if entries.isEmpty {
                            EmptyStateView(symbol: "chart.bar", title: "这里还没有排名", message: "先录入自己的身体数据（含体重）和卧推力量记录，便可参与排名。")
                        } else {
                            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                                rankingRow(entry, position: index + 1)
                            }
                        }
                    }

                    Text("此榜由本机示例人物和你的记录组成。排名仅表示这些记录之间的顺序，不代表真实人群百分位。")
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
            .navigationTitle("榜单")
            .sheet(isPresented: $showsRules) {
                leaderboardRules
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .accessibilityIdentifier("leaderboardScreen")
        }
    }

    private var rulesButton: some View {
        Button { showsRules = true } label: {
            Image(systemName: "info.circle")
                .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel("查看榜单说明")
        .accessibilityIdentifier("leaderboardInfoButton")
    }

    private func rankingRow(_ entry: RankEntry, position: Int) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    rankPerson(entry, position: position)
                    rankValue(entry)
                        .padding(.leading, 36)
                }
            } else {
                HStack(spacing: 12) {
                    rankPerson(entry, position: position)
                    Spacer(minLength: 5)
                    rankValue(entry).fixedSize()
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("第\(position)名，\(entry.name)\(entry.isCurrentUser ? "，我" : "")，卧推体重比\(ratio(entry.value))倍")
        .accessibilityIdentifier("rankEntry-\(entry.id)")
    }

    private func rankPerson(_ entry: RankEntry, position: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(position)")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(position <= 3 ? KaXTheme.accent : KaXTheme.muted)
                .frame(minWidth: 24)
            AvatarView(initials: entry.initials)
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name)
                    .font(.subheadline.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                if entry.isCurrentUser {
                    Text("我").font(.caption2.weight(.medium)).foregroundStyle(KaXTheme.accent)
                }
            }
        }
    }

    private func rankValue(_ entry: RankEntry) -> some View {
        Text("\(ratio(entry.value)) ×")
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(entry.isCurrentUser ? KaXTheme.accent : KaXTheme.ink)
    }

    private func currentMetric(_ entry: RankEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("我的卧推体重比").font(.caption).foregroundStyle(KaXTheme.muted)
            MetricValue(value: ratio(entry.value), unit: "×")
        }
    }

    private func currentPosition(_ position: Int) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("第 \(position) 名").font(.title3.weight(.semibold)).foregroundStyle(KaXTheme.accent)
            Text("\(entries.count) 人示例榜").font(.caption).foregroundStyle(KaXTheme.muted)
        }
    }

    private func ratio(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(2)))
    }

    private var leaderboardRules: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("卧推估计 1RM ÷ 体重")
                        .font(.title2.weight(.semibold))
                    Text("根据记录的重量与次数估计单次最大重量，再除以体重。例如，估计单次最大重量为 70 kg、体重 70 kg，显示为 1.00 倍。")
                        .fixedSize(horizontal: false, vertical: true)
                    Text("榜单按体重比从高到低排列。切换到关注，只显示你和已关注的示例好友。")
                        .fixedSize(horizontal: false, vertical: true)
                    RoundedPanel {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("示例榜单").font(.headline)
                            Text("好友为示例人物，你的数值来自本机记录。这不是联网赛事，也不是对全球人群的统计。")
                                .font(.subheadline)
                                .foregroundStyle(KaXTheme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(24)
                .pageWidth()
            }
            .background(KaXTheme.background)
            .navigationTitle("榜单说明")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { showsRules = false }
                }
            }
        }
    }
}
