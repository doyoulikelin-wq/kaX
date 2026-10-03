import SwiftUI
import UniformTypeIdentifiers

struct ProfileView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicType
    @State private var editing = false
    @State private var settings = false
    @State private var sharePayload: CardSharePayload?
    @State private var shareError: String?
    @State private var rankingDetail: ProfileRankingDetailPayload?

    private var validRankingMeasurements: [RankingMeasurement] {
        store.rankingMeasurements.filter {
            $0.personID == store.profile.id && (try? $0.calculatedValue()) != nil
        }
    }

    private var independentRankingMeasurements: [RankingMeasurement] {
        let ids = Set(store.staticMeasurements.map(\.id))
        return validRankingMeasurements.filter { $0.sourceRecordID.map { !ids.contains($0) } ?? true }
    }

    private var measurementItems: [ProfileMeasurementItem] {
        let items = store.records.map(ProfileMeasurementItem.legacy)
            + independentRankingMeasurements.map(ProfileMeasurementItem.ranking)
            + store.staticMeasurements.map(ProfileMeasurementItem.staticRecord)
        return items.sorted {
            $0.date == $1.date ? $0.id < $1.id : $0.date > $1.date
        }
    }

    private var monthlyMeasurementCount: Int {
        let isThisMonth: (Date) -> Bool = {
            Calendar.current.isDate($0, equalTo: Date(), toGranularity: .month)
        }
        return store.records.filter { $0.origin != .demo && isThisMonth($0.date) }.count
            + independentRankingMeasurements.filter { $0.origin != .demo && isThisMonth($0.date) }.count
            + store.staticMeasurements.filter { $0.origin != .demo && isThisMonth($0.date) }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    let headerLayout = dynamicType.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14)) : AnyLayout(HStackLayout(spacing: 14))
                    headerLayout {
                        AvatarView(initials: String(store.profile.name.prefix(1)), size: 58)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(store.profile.name).font(.title2.bold())
                            Text(store.profile.handle).font(.subheadline).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
                        }
                        if !dynamicType.isAccessibilitySize { Spacer() }
                        Button("编辑") { editing = true }
                            .font(.subheadline.weight(.medium))
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("editProfileButton")
                    }
                    if !store.profile.bio.isEmpty {
                        Text(store.profile.bio).font(.subheadline).foregroundStyle(.secondary)
                    }
                    IdentityCardView(profile: store.profile, record: featuredRecord, rank: featuredRank)
                        .accessibilityIdentifier("identityCard")
                    let actionsLayout = dynamicType.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
                    actionsLayout {
                        Button(action: prepareCardShare) {
                            Label("分享卡片", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity).padding(.vertical, 8)
                        }.buttonStyle(.borderedProminent).accessibilityIdentifier("shareCardButton")
                        Button { editing = true } label: {
                            Label("定制展示", systemImage: "slider.horizontal.3")
                                .frame(maxWidth: .infinity).padding(.vertical, 8)
                        }.buttonStyle(.bordered).accessibilityIdentifier("customizeCardButton")
                    }.font(.subheadline.weight(.medium))
                    VStack(spacing: 14) {
                        SectionHeading(title: "身体档案", subtitle: "让每一次变化有迹可循")
                        RoundedPanel {
                            LazyVGrid(columns: dynamicType.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 24) {
                                profileMetric("身高", value: store.profile.heightCM, unit: "cm")
                                profileMetric("体重", value: store.profile.weightKG, unit: "kg")
                                profileMetric("臂展", value: store.profile.armSpanCM, unit: "cm")
                                profileMetric("腰围", value: store.profile.waistCM, unit: "cm")
                            }
                            HStack {
                                Spacer()
                                OriginBadge(origin: store.latestBody?.origin ?? .demo)
                            }.padding(.top, 12)
                        }
                    }
                    VStack(spacing: 14) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("最近测量").font(.headline)
                            Spacer(minLength: 12)
                            Text("\(measurementItems.count) 条记录")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("recentMeasurementCount")
                        }
                        if measurementItems.isEmpty {
                            Text("完成一次测量，你的记录会出现在这里。")
                                .foregroundStyle(.secondary).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        ForEach(measurementItems.prefix(4)) { item in
                            switch item {
                            case .legacy(let record):
                                NavigationLink {
                                    ProfileRecordDetail(record: record)
                                } label: {
                                    recentMeasurementRow(item)
                                }
                                .buttonStyle(.plain)
                            case .staticRecord(let record):
                                NavigationLink { StaticMeasurementRecordDetailView(record: record) } label: { recentMeasurementRow(item) }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("recentStatic-\(record.id.uuidString)")
                            case .ranking(let measurement):
                                Button {
                                    guard let value = try? measurement.calculatedValue() else { return }
                                    let entry = EvidenceRankEntry(id: store.profile.id, name: store.profile.name, initials: String(store.profile.name.prefix(1)), value: value, position: 0, isCurrentUser: true, measurement: measurement)
                                    rankingDetail = ProfileRankingDetailPayload(entry: entry)
                                } label: {
                                    recentMeasurementRow(item)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("recentRanking-\(measurement.id.uuidString)")
                            }
                        }
                    }
                    Text("本机体验 · 示例好友与历史记录用于展示产品流程")
                        .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }.padding(20).pageWidth()
            }
            .background(KaXTheme.background)
            .navigationTitle("我的")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { settings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("设置").accessibilityIdentifier("settingsButton")
                }
            }
            .sheet(isPresented: $editing) { EditProfileView(profile: store.profile) }
            .sheet(isPresented: $settings) { SettingsView() }
            .sheet(item: $rankingDetail) { payload in
                RankingEntryDetailView(metric: payload.entry.measurement.metric, entry: payload.entry)
                    .environment(store)
            }
            .sheet(item: $sharePayload) { payload in ActivityShareView(items: [payload.url, shareText]) }
            .alert("暂时无法生成卡片", isPresented: Binding(get: { shareError != nil }, set: { if !$0 { shareError = nil } })) {
                Button("知道了") { shareError = nil }
            } message: { Text(shareError ?? "") }
            .accessibilityIdentifier("profileScreen")
        }
    }

    private var featuredRecord: MeasurementRecord? {
        switch store.profile.featuredMetric {
        case .benchPress: store.latestStrength
        case .armSpan:
            if let entry = featuredArmSpanEntry {
                MeasurementRecord(date: entry.measurement.date, kind: .body, title: "臂展比例", value: entry.value, unit: "× 身高", origin: entry.measurement.origin)
            } else if let body = store.latestBody, store.profile.heightCM > 0 {
                MeasurementRecord(date: body.date, kind: .body, title: "臂展比例", value: store.profile.armSpanCM / store.profile.heightCM, unit: "× 身高", origin: body.origin)
            } else { nil }
        case .consistency:
            MeasurementRecord(kind: .body, title: "本月测量", value: Double(monthlyMeasurementCount), unit: "次", origin: .manual)
        }
    }

    private var featuredArmSpanEntry: EvidenceRankEntry? {
        guard let entry = store.rankingEntries(for: .armSpanRatio).first(where: \.isCurrentUser) else { return nil }
        // A newer legacy body record remains visible, but does not gain a protocol it never recorded.
        if let body = store.latestBody, body.date > entry.measurement.date { return nil }
        return entry
    }

    private var featuredRank: Int? {
        guard store.profile.featuredMetric == .armSpan else { return nil }
        return featuredArmSpanEntry?.position
    }

    private var shareText: String {
        let record = featuredRecord
        let value = record.map(profileRecordShareSummary) ?? "我的第一张测量卡"
        return "\(store.profile.name) 的 kaX 身份卡\n\(value)\n记录身体，分享变化。"
    }

    @MainActor private func prepareCardShare() {
        let content = IdentityCardView(profile: store.profile, record: featuredRecord, rank: featuredRank)
            .frame(width: 350).padding(24)
            .background(Color(uiColor: .systemBackground))
            .environment(\.colorScheme, .light).dynamicTypeSize(.medium)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 3
        guard let data = renderer.uiImage?.pngData() else { shareError = "请稍后重试。"; return }
        do {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("kaX-identity-card.png")
            try data.write(to: url, options: .atomic)
            sharePayload = CardSharePayload(url: url)
        } catch { shareError = error.localizedDescription }
    }

    private func profileMetric(_ title: String, value: Double, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value, format: .number.precision(.fractionLength(0...1))).font(.title2.weight(.semibold)).monospacedDigit().fixedSize()
                    Text(unit).font(.caption).foregroundStyle(.secondary).fixedSize()
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(value, format: .number.precision(.fractionLength(0...1))).font(.title2.weight(.semibold)).monospacedDigit()
                    Text(unit).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func recentMeasurementRow(_ item: ProfileMeasurementItem) -> some View {
        let layout = dynamicType.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 13))
        return layout {
            HStack(alignment: .top, spacing: 13) {
                Image(systemName: item.symbol)
                    .font(.title3).foregroundStyle(KaXTheme.accent)
                    .frame(width: 44, height: 44)
                    .background(KaXTheme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(item.date, format: .dateTime.month().day())
                        .font(.caption).foregroundStyle(.secondary)
                    OriginBadge(origin: item.origin)
                }
            }
            if !dynamicType.isAccessibilitySize { Spacer(minLength: 0) }
            Text(item.valueText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            if !dynamicType.isAccessibilitySize {
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .background(KaXTheme.card, in: RoundedRectangle(cornerRadius: 18))
    }
}

private enum ProfileMeasurementItem: Identifiable {
    case legacy(MeasurementRecord)
    case ranking(RankingMeasurement)
    case staticRecord(StaticMeasurementRecord)

    var id: String {
        switch self {
        case .legacy(let record): return "legacy-\(record.id.uuidString)"
        case .ranking(let record): return "ranking-\(record.id.uuidString)"
        case .staticRecord(let record): return "static-\(record.id.uuidString)"
        }
    }
    var date: Date {
        switch self {
        case .legacy(let record): return record.date
        case .ranking(let record): return record.date
        case .staticRecord(let record): return record.date
        }
    }
    var title: String {
        switch self {
        case .legacy(let record): return record.title
        case .ranking(let record): return record.metric.title
        case .staticRecord(let record): return StaticFeatureCatalog.metadata(for: record.feature)?.title ?? record.feature.rawValue
        }
    }
    var symbol: String {
        switch self {
        case .legacy(let record): return record.kind.systemImage
        case .ranking: return "ruler"
        case .staticRecord: return "ruler"
        }
    }
    var origin: DataOrigin {
        switch self {
        case .legacy(let record): return record.origin
        case .ranking(let record): return record.origin
        case .staticRecord(let record): return record.origin
        }
    }
    var valueText: String {
        switch self {
        case .legacy(let record):
            return "\(record.value.formatted(.number.precision(.fractionLength(0...1)))) \(record.unit)"
        case .staticRecord(let record):
            guard let value = record.result.values.first else { return "已记录" }
            return "\(value.value.formatted(.number.precision(.fractionLength(0...2)))) \(value.unit)"
        case .ranking(let record):
            guard let value = try? record.calculatedValue() else { return "未记录" }
            return "\(record.metric.formattedValue(value)) \(record.metric.unit)"
        }
    }
}

private struct ProfileRankingDetailPayload: Identifiable {
    let entry: EvidenceRankEntry
    var id: UUID { entry.measurement.id }
}

private struct CardSharePayload: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ActivityShareView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

struct IdentityCardView: View {
    let profile: UserProfile
    let record: MeasurementRecord?
    var rank: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 27) {
            HStack {
                Text("kaX").font(.system(size: 25, weight: .bold, design: .rounded))
                Spacer()
                Text("MEASURE. SHARE.").font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1.4).foregroundStyle(.white.opacity(0.55))
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(profile.featuredMetric.title)
                    Spacer()
                    if let rank { Text("示例榜 #\(rank)") }
                }.font(.subheadline).foregroundStyle(.white.opacity(0.62))
                if let record {
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text(record.value, format: .number.precision(.fractionLength(0...(profile.featuredMetric == .armSpan ? 2 : 1))))
                            .font(.system(size: 54, weight: .medium, design: .rounded)).monospacedDigit()
                            .accessibilityIdentifier("identityMetricValue")
                        Text(record.unit).font(.title3).foregroundStyle(.white.opacity(0.6))
                        if record.kind == .strength, let repetitions = record.secondaryValue {
                            Text("× \(Int(repetitions))").font(.title3).foregroundStyle(.white.opacity(0.6))
                        }
                    }
                } else {
                    Text("等待你的第一次测量").font(.title3.weight(.medium))
                }
            }
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(profile.name).font(.subheadline.weight(.semibold))
                    Text(profile.handle).font(.caption).foregroundStyle(.white.opacity(0.48))
                }
                Spacer()
                if let record {
                    VStack(alignment: .trailing, spacing: 5) {
                        Text(record.origin.title).font(.caption2)
                        Text(record.date, format: .dateTime.year().month().day()).font(.caption2)
                    }.foregroundStyle(.white.opacity(0.55))
                }
            }
        }
        .foregroundStyle(.white)
        .padding(25)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.10, green: 0.13, blue: 0.12), in: RoundedRectangle(cornerRadius: 26))
    }
}

private struct EditProfileView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var profile: UserProfile
    @State private var saveError: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("个人资料") {
                    TextField("昵称", text: $profile.name).accessibilityIdentifier("profileNameField")
                    TextField("一句话介绍自己", text: $profile.bio, axis: .vertical)
                        .lineLimit(2...4).accessibilityIdentifier("profileBioField")
                }
                Section {
                    Picker("主展示指标", selection: $profile.featuredMetric) {
                        ForEach(FeaturedMetric.allCases, id: \.self) { metric in Text(metric.title).tag(metric) }
                    }.accessibilityIdentifier("featuredMetricPicker")
                } header: {
                    Text("卡面展示")
                } footer: {
                    Text("选择一个最能代表你的指标，显示在身份卡上。")
                }
                Section {
                    Picker("分享范围", selection: $profile.visibility) {
                        ForEach(ProfileVisibility.allCases, id: \.self) { visibility in Text(visibility.title).tag(visibility) }
                    }.accessibilityIdentifier("profileVisibilityPicker")
                } footer: {
                    Text("本机体验中的内容仅保存在这台设备。主动分享时，你可以自行选择接收人。")
                }
            }
            .navigationTitle("编辑身份卡").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        profile.name = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        profile.bio = String(profile.bio.prefix(120))
                        store.saveProfile(profile)
                        if let error = store.persistenceError {
                            saveError = error
                        } else {
                            dismiss()
                        }
                    }
                    .disabled(profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || profile.name.count > 24)
                    .accessibilityIdentifier("saveProfileButton")
                }
            }
            .alert("资料未能保存", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
                Button("知道了") { saveError = nil }
            } message: { Text(saveError ?? "") }
        }
    }
}

private struct ProfileRecordDetail: View {
    let record: MeasurementRecord
    var body: some View {
        List {
            Section {
                MetricValue(value: record.value.formatted(.number.precision(.fractionLength(0...1))), unit: record.unit)
                    .padding(.vertical, 20)
                LabeledContent("来源", value: record.origin.title)
                LabeledContent("日期", value: record.date.formatted(date: .abbreviated, time: .shortened))
                if record.kind == .strength, let repetitions = record.secondaryValue {
                    LabeledContent("次数", value: "\(Int(repetitions)) 次")
                }
                if !record.note.isEmpty { Text(record.note).foregroundStyle(.secondary) }
            }
            Section {
                ShareLink(item: "\(profileRecordShareSummary(record))\n来自 kaX") {
                    Label("分享这次测量", systemImage: "square.and.arrow.up")
                }
            }
        }.navigationTitle(record.title).navigationBarTitleDisplayMode(.inline)
    }
}

private func profileRecordShareSummary(_ record: MeasurementRecord) -> String {
    var summary = "\(record.title)：\(record.value.formatted()) \(record.unit)"
    if record.kind == .strength, let repetitions = record.secondaryValue {
        summary += " × \(repetitions.formatted(.number.precision(.fractionLength(0)))) 次"
    }
    return "\(summary) · \(record.origin.title)"
}

private struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var exporting = false
    @State private var exportDocument = AppExportDocument(data: Data())
    @State private var confirmingReset = false
    @State private var operationError: String?
    @State private var operationErrorTitle = "操作未能完成"

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("本机体验", systemImage: "iphone")
                    Text("你的测量、编辑和互动会保存在这台设备。动态中的示例用户用于体验社交流程。")
                        .font(.subheadline).foregroundStyle(.secondary)
                } header: { Text("当前空间") }
                Section("数据") {
                    Button {
                        operationError = nil
                        if let data = store.exportData() {
                            exportDocument = AppExportDocument(data: data)
                            exporting = true
                        } else {
                            operationErrorTitle = "导出失败"
                            operationError = store.persistenceError ?? "暂时无法导出，请重试。"
                        }
                    } label: { Label("导出我的数据", systemImage: "square.and.arrow.up") }
                        .accessibilityIdentifier("exportDataButton")
                    Text("JSON 包含原始数据、结果与照片引用；图片保存在本机，不包含在 JSON 内。")
                        .font(.caption).foregroundStyle(.secondary)
                    Button(role: .destructive) { confirmingReset = true } label: {
                        Label("重置本机体验", systemImage: "arrow.counterclockwise")
                    }.accessibilityIdentifier("resetDemoButton")
                }
                if let operationError {
                    Section(operationErrorTitle) {
                        Text(operationError)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("settingsOperationError")
                    }
                }
                Section("关于") {
                    LabeledContent("kaX", value: "0.1.0")
                    Text("记录身体，分享变化。")
                        .foregroundStyle(.secondary)
                    Text("示例排行用于体验比较方式。手动记录与设备测量保留各自来源；肌电结果用于查看特定动作的电活动。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("设置").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
            .confirmationDialog("重置本机体验？", isPresented: $confirmingReset, titleVisibility: .visible) {
                Button("删除本机记录并重置", role: .destructive) {
                    operationError = nil
                    store.resetDemo()
                    if let error = store.persistenceError {
                        operationErrorTitle = "重置失败"
                        operationError = error
                    } else {
                        do { try StaticPhotoFiles.removeAll() }
                        catch { operationErrorTitle = "照片清理未完成"; operationError = "记录已重置，照片清理失败：\(error.localizedDescription)" }
                    }
                }
            } message: { Text("你新增的测量、采集照片、动态和个人编辑将被删除。JSON 导出包含数据与照片引用，不包含图片本身。") }
            .fileExporter(isPresented: $exporting, document: exportDocument, contentType: .json, defaultFilename: "kaX-data") { result in
                if case .failure(let error) = result {
                    operationErrorTitle = "导出失败"
                    operationError = error.localizedDescription
                }
            }
            .alert(operationErrorTitle, isPresented: Binding(get: { operationError != nil }, set: { if !$0 { operationError = nil } })) {
                Button("知道了") { operationError = nil }
            } message: { Text(operationError ?? "") }
        }
    }
}

private struct AppExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
