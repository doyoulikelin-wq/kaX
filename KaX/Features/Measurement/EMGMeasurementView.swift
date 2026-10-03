import SwiftUI

struct EMGMeasurementView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var phase: EMGDemoPhase = .ready
    @State private var samples: [Double] = []
    @State private var progress = 0.0
    @State private var acquisitionTask: Task<Void, Never>?
    @State private var activeDevice: (any MeasurementDevice)?
    @State private var acquisitionError: String?

    private var rms: Double {
        guard !samples.isEmpty else { return 0 }
        return sqrt(samples.reduce(0) { $0 + $1 * $1 } / Double(samples.count))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("肌电采集")
                                .font(.title2.bold())
                            Text("5 秒演示")
                                .font(.subheadline)
                                .foregroundStyle(KaXTheme.muted)
                        }
                        Spacer()
                        OriginBadge(origin: .demo)
                    }

                    RoundedPanel {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "waveform")
                                .foregroundStyle(KaXTheme.accent)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("设备未连接")
                                    .font(.subheadline.weight(.semibold))
                                Text("下面使用模拟信号展示采集过程，保存后会标记为演示。")
                                    .font(.footnote)
                                    .foregroundStyle(KaXTheme.muted)
                            }
                            Spacer(minLength: 0)
                        }
                    }

                    RoundedPanel {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("模拟信号")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text("mV")
                                    .font(.caption)
                                    .foregroundStyle(KaXTheme.muted)
                            }
                            ZStack {
                                EMGGraphGrid()
                                    .stroke(KaXTheme.line, lineWidth: 1)
                                EMGWaveform(samples: samples)
                                    .stroke(KaXTheme.accent, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                                if samples.isEmpty {
                                    Text("等待开始")
                                        .font(.subheadline)
                                        .foregroundStyle(KaXTheme.muted)
                                }
                            }
                            .frame(height: 180)
                            .clipped()
                            .accessibilityLabel(samples.isEmpty ? "等待采集的模拟肌电曲线" : "模拟肌电信号曲线")
                            .accessibilityIdentifier("emgWaveform")

                            HStack {
                                Text(statusText)
                                    .font(.caption)
                                    .foregroundStyle(KaXTheme.muted)
                                Spacer()
                                Text("\(String(format: "%.1f", progress * 5)) / 5.0 秒")
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundStyle(KaXTheme.muted)
                            }
                            ProgressView(value: progress)
                                .tint(KaXTheme.accent)
                                .accessibilityIdentifier("emgAcquisitionProgress")
                        }
                    }

                    if phase == .complete {
                        RoundedPanel {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("模拟 RMS")
                                    .font(.subheadline)
                                    .foregroundStyle(KaXTheme.muted)
                                MetricValue(value: MeasurementFormatting.number(rms, precision: 3), unit: "mV")
                                Text("模拟信号的幅度摘要")
                                    .font(.footnote)
                                    .foregroundStyle(KaXTheme.muted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .accessibilityIdentifier("emgDemoResult")

                        MeasurementSaveButton(title: "保存演示记录") {
                            saveDemo()
                        }
                        .accessibilityIdentifier("saveEMGButton")

                        Button("重新采集") { startAcquisition() }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(KaXTheme.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .accessibilityIdentifier("startEMGButton")
                    } else if phase == .collecting {
                        Button {
                            cancelAcquisition()
                        } label: {
                            Text("取消采集")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 17)
                                .background(KaXTheme.card, in: RoundedRectangle(cornerRadius: 17))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 17)
                                        .stroke(KaXTheme.line, lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("cancelEMGButton")
                    } else {
                        MeasurementSaveButton(title: "开始演示采集") {
                            startAcquisition()
                        }
                        .accessibilityIdentifier("startEMGButton")
                    }

                    if let acquisitionError {
                        Text(acquisitionError)
                            .font(.footnote)
                            .foregroundStyle(KaXTheme.muted)
                    }

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
            .navigationTitle("肌电")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        cancelAcquisition()
                        dismiss()
                    }
                    .foregroundStyle(KaXTheme.ink)
                }
            }
            .onDisappear {
                cancelAcquisition()
            }
        }
        .accessibilityIdentifier("emgMeasurementScreen")
    }

    private var statusText: String {
        switch phase {
        case .ready: "准备开始"
        case .collecting: "正在采集演示信号"
        case .complete: "演示采集完成"
        }
    }

    @MainActor
    private func startAcquisition() {
        acquisitionTask?.cancel()
        stopActiveDevice()
        samples = []
        progress = 0
        acquisitionError = nil
        phase = .collecting
        let device: any MeasurementDevice = DemoMeasurementDevice(sampleCount: 200, sampleInterval: 0.025)
        activeDevice = device
        acquisitionTask = Task { @MainActor in
            do {
                try await device.prepare()
                guard !Task.isCancelled else {
                    await device.stop()
                    return
                }
                let stream = try await device.start()
                for try await sample in stream {
                    guard !Task.isCancelled else {
                        await device.stop()
                        return
                    }
                    guard sample.value.isFinite, sample.timestamp.isFinite else { continue }
                    samples.append(sample.value)
                    progress = min(1, (sample.timestamp + 0.025) / 5)
                }
                guard !Task.isCancelled else { return }
                if !samples.isEmpty {
                    progress = 1
                    phase = .complete
                } else {
                    phase = .ready
                    acquisitionError = "没有收到演示信号，请重新开始。"
                }
                activeDevice = nil
                acquisitionTask = nil
                await device.stop()
            } catch {
                await device.stop()
                guard !Task.isCancelled else { return }
                phase = .ready
                activeDevice = nil
                acquisitionTask = nil
                acquisitionError = "演示采集未完成，请重新开始。"
            }
        }
    }

    private func cancelAcquisition() {
        acquisitionTask?.cancel()
        acquisitionTask = nil
        stopActiveDevice()
        samples = []
        progress = 0
        phase = .ready
    }

    private func stopActiveDevice() {
        let device = activeDevice
        activeDevice = nil
        Task { await device?.stop() }
    }

    private func saveDemo() {
        guard phase == .complete, !samples.isEmpty, rms.isFinite else { return }
        let record = MeasurementRecord(
            id: UUID(),
            date: Date(),
            kind: .emg,
            title: "演示肌电",
            value: rms,
            unit: "mV",
            secondaryValue: 5,
            origin: .demo,
            note: "模拟 RMS · 5 秒演示信号；设备未连接。"
        )
        store.addRecord(record)
        if store.persistenceError == nil { dismiss() }
    }
}

private enum EMGDemoPhase {
    case ready, collecting, complete
}

private struct EMGWaveform: Shape {
    let samples: [Double]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard samples.count > 1 else { return path }
        for (index, sample) in samples.enumerated() {
            let x = rect.minX + CGFloat(index) / 199 * rect.width
            let y = rect.midY - CGFloat(sample / 0.5) * rect.height / 2
            let point = CGPoint(x: x, y: y)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }
}

private struct EMGGraphGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for row in 0...4 {
            let y = rect.minY + CGFloat(row) / 4 * rect.height
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        for column in 0...5 {
            let x = rect.minX + CGFloat(column) / 5 * rect.width
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
        }
        return path
    }
}
