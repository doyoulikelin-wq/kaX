import SwiftUI

struct StaticMeasurementCatalogView: View {
    @Environment(AppStore.self) private var store
    @State private var searchText = ""
    @State private var selectedGroup = "全部"

    private var groups: [String] {
        ["全部"] + StaticFeatureCatalog.all.map(\.group).reduce(into: [String]()) { result, group in
            if !result.contains(group) { result.append(group) }
        }
    }

    private var visibleFeatures: [StaticFeatureMetadata] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return StaticFeatureCatalog.all.filter { feature in
            (selectedGroup == "全部" || feature.group == selectedGroup) &&
            (query.isEmpty || "\(feature.id.rawValue) \(feature.title) \(feature.category) \(feature.group) \(feature.data)".localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("从静态数据，认识自己的身体。")
                        .font(.title3.weight(.semibold))
                    Text("\(StaticFeatureCatalog.all.count) 项目录 · 原始输入、计算方法与来源可追溯")
                        .font(.subheadline).foregroundStyle(.secondary)
                }

                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("搜索名称、编号或测量内容", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                        .accessibilityIdentifier("staticCatalogSearchField")
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .foregroundStyle(.secondary).accessibilityLabel("清除搜索")
                    }
                }
                .padding(14)
                .background(KaXTheme.card, in: RoundedRectangle(cornerRadius: 14))

                Picker("目录分类", selection: $selectedGroup) {
                    ForEach(groups, id: \.self) { group in Text(group).tag(group) }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("staticCatalogGroupPicker")

                NavigationLink {
                    StaticMeasurementHistoryView()
                } label: {
                    Label("本机测量历史（\(store.staticMeasurements.count)）", systemImage: "clock.arrow.circlepath")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityIdentifier("staticMeasurementHistoryButton")

                if let message = StaticFeatureCatalog.loadingError {
                    RoundedPanel {
                        EmptyStateView(symbol: "doc.text.magnifyingglass", title: "目录暂不可用", message: message)
                    }
                } else if visibleFeatures.isEmpty {
                    EmptyStateView(symbol: "magnifyingglass", title: "没有匹配项目", message: "试试其他名称或分类。")
                } else {
                    ForEach(groups.filter { $0 != "全部" }, id: \.self) { group in
                        let features = visibleFeatures.filter { $0.group == group }
                        if !features.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeading(title: group, trailing: "\(features.count) 项")
                                ForEach(features, id: \.id) { feature in
                                    NavigationLink {
                                        StaticFeatureDetailView(feature: feature)
                                    } label: {
                                        featureRow(feature)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("staticFeature-\(feature.id.rawValue)")
                                }
                            }
                        }
                    }
                }
            }
            .padding(20).pageWidth()
        }
        .background(KaXTheme.background)
        .navigationTitle("静态身体测量")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                    .accessibilityIdentifier("keyboardDoneButton")
            }
        }
        .accessibilityIdentifier("staticMeasurementCatalogScreen")
    }

    private func featureRow(_ feature: StaticFeatureMetadata) -> some View {
        RoundedPanel {
            VStack(alignment: .leading, spacing: 9) {
                Text("\(feature.id.rawValue) · \(feature.category)")
                    .font(.caption).foregroundStyle(.secondary)
                HStack(alignment: .top, spacing: 10) {
                    Text(feature.title).font(.headline).foregroundStyle(KaXTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                }
                Text(feature.availability == .requiresReferenceLibrary ? "需连接参考库 · 查看方法与依赖" : "查看方法与依据 · 录入原始数据")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct StaticMeasurementHistoryView: View {
    @Environment(AppStore.self) private var store
    var featureID: StaticFeatureID? = nil

    private var records: [StaticMeasurementRecord] {
        store.staticMeasurements.filter { featureID == nil || $0.feature == featureID }
            .sorted { $0.date == $1.date ? $0.id.uuidString < $1.id.uuidString : $0.date > $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("每次计算都保留原始输入与采集来源。")
                    .font(.subheadline).foregroundStyle(.secondary)
                if records.isEmpty {
                    EmptyStateView(symbol: "ruler", title: "还没有这类记录", message: "选择一个项目，录入并保存你的测量。")
                } else {
                    ForEach(records) { record in
                        NavigationLink {
                            StaticMeasurementRecordDetailView(record: record)
                        } label: {
                            StaticMeasurementHistoryRow(record: record)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("staticRecord-\(record.id.uuidString)")
                    }
                }
            }
            .padding(20).pageWidth()
        }
        .background(KaXTheme.background)
        .navigationTitle("测量历史")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("staticMeasurementHistoryScreen")
    }
}

struct StaticMeasurementHistoryRow: View {
    let record: StaticMeasurementRecord

    var body: some View {
        RoundedPanel {
            VStack(alignment: .leading, spacing: 9) {
                Text(StaticFeatureCatalog.metadata(for: record.feature)?.title ?? record.feature.rawValue)
                    .font(.headline).foregroundStyle(KaXTheme.ink)
                if let first = record.result.values.first {
                    Text("\(first.title)：\(StaticMeasurementFormatting.number(first.value)) \(first.unit)")
                        .font(.subheadline.weight(.medium)).foregroundStyle(KaXTheme.ink)
                        .monospacedDigit().fixedSize(horizontal: false, vertical: true)
                }
                ViewThatFits(in: .horizontal) {
                    HStack { Text(record.date.formatted(date: .abbreviated, time: .shortened)); OriginBadge(origin: record.origin) }
                    VStack(alignment: .leading, spacing: 6) { Text(record.date.formatted(date: .abbreviated, time: .shortened)); OriginBadge(origin: record.origin) }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

enum StaticMeasurementFormatting {
    static func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...4)))
    }
}
