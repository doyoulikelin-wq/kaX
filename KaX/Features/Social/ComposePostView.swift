import SwiftUI

struct ComposePostView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var caption = ""
    @State private var selectedRecordID: UUID?
    @State private var showsSaveError = false

    private var recentRecords: [MeasurementRecord] {
        Array(store.records.sorted { $0.date > $1.date }.prefix(8))
    }

    private var canPublish: Bool {
        !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedRecordID != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    RoundedPanel {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 10) {
                                AvatarView(initials: socialInitials(store.profile.name))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(store.profile.name).font(.subheadline.weight(.semibold))
                                    Text("发布到本机动态")
                                        .font(.caption)
                                        .foregroundStyle(KaXTheme.muted)
                                }
                            }
                            TextField("这次有什么新发现？", text: $caption, axis: .vertical)
                                .font(.body)
                                .lineLimit(4...8)
                                .accessibilityLabel("动态文字")
                                .accessibilityIdentifier("postCaptionField")
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeading(title: "附上一次测量", subtitle: "选择最近记录，也可以只分享文字")
                        recordChoice(record: nil)
                        ForEach(recentRecords) { record in
                            recordChoice(record: record)
                        }
                        if recentRecords.isEmpty {
                            Text("还没有测量记录。你可以先发布一条文字动态。")
                                .font(.footnote)
                                .foregroundStyle(KaXTheme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Text("当前为本机体验空间。动态保存在此设备，分享时会打开系统分享面板。")
                        .font(.caption)
                        .foregroundStyle(KaXTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
                .pageWidth()
            }
            .background(KaXTheme.background)
            .navigationTitle("发布动态")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("发布", action: publish)
                        .fontWeight(.semibold)
                        .disabled(!canPublish)
                        .accessibilityIdentifier("publishPostButton")
                }
            }
            .alert("动态未能保存", isPresented: $showsSaveError) {
                Button("好", role: .cancel) { }
            } message: {
                Text(store.persistenceError ?? "请稍后重试。")
            }
        }
    }

    private func recordChoice(record: MeasurementRecord?) -> some View {
        let isSelected = selectedRecordID == record?.id
        return Button {
            selectedRecordID = record?.id
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? KaXTheme.accent : KaXTheme.muted)
                    .font(.title3)
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 10) {
                        recordDescription(record)
                        if let record {
                            recordValue(record)
                        }
                    }
                    Spacer(minLength: 0)
                } else {
                    recordDescription(record)
                    Spacer(minLength: 6)
                    if let record {
                        recordValue(record)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KaXTheme.card, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? KaXTheme.accent.opacity(0.6) : KaXTheme.line, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(record.map { "选择\($0.title)，\(recordSummary($0))，\($0.origin.title)" } ?? "只发布文字")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(record.map { "recordSelection-\($0.id.uuidString)" } ?? "textOnlyPostButton")
    }

    private func recordDescription(_ record: MeasurementRecord?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(record?.title ?? "只发文字")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(KaXTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let record {
                Text("\(record.kind.title) · \(record.date.formatted(.dateTime.month().day()))")
                    .font(.caption)
                    .foregroundStyle(KaXTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func recordValue(_ record: MeasurementRecord) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(recordSummary(record))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(KaXTheme.ink)
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
            OriginBadge(origin: record.origin)
        }
    }

    private func recordSummary(_ record: MeasurementRecord) -> String {
        let amount = "\(socialMetric(record.value)) \(record.unit)"
        if record.kind == .strength, let repetitions = record.secondaryValue {
            return "\(amount) × \(socialMetric(repetitions)) 次"
        }
        return amount
    }

    private func publish() {
        guard canPublish else { return }
        store.publish(caption: caption.trimmingCharacters(in: .whitespacesAndNewlines), recordID: selectedRecordID)
        if store.persistenceError == nil {
            dismiss()
        } else {
            showsSaveError = true
        }
    }
}
