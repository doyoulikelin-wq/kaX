import SwiftUI
import PhotosUI
import Vision

enum StaticPhotoFiles {
    static var directory: URL {
        let base = ProcessInfo.processInfo.arguments.contains("--uitesting")
            ? FileManager.default.temporaryDirectory.appendingPathComponent("kax-ui-test-photos")
            : FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("kaX/StaticPhotos")
        return base
    }
    static func save(_ image: UIImage) throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.95) else { throw StaticPhotoError.message("无法保存照片。") }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let id = UUID().uuidString
        try data.write(to: directory.appendingPathComponent(id + ".jpg"), options: .atomic)
        return id
    }
    static func removeAll() throws {
        if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
    }
    static func image(for id: String) -> UIImage? {
        guard UUID(uuidString: id) != nil else { return nil }
        return UIImage(contentsOfFile: directory.appendingPathComponent(id + ".jpg").path)
    }
    static func normalized(_ image: UIImage) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        let ratio = min(1, 2048 / max(longest, 1))
        let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }
}

struct StaticPhotoMeasurementView: View {
    let feature: StaticFeatureID
    let onApply: (StaticMeasurementInput) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var points: [String: CGPoint] = [:]
    @State private var selectedPoint = "referenceA"
    @State private var referenceLength = ""
    @State private var side = "右"
    @State private var samePlane = false
    @State private var corrected = false
    @State private var level = false
    @State private var confirmed = false
    @State private var modelRevision: String?
    @State private var detecting = false
    @State private var message: String?
    @State private var captureVersion = UUID()

    private var pointLabels: [(String, String)] {
        let reference = [("referenceA", "参照物起点"), ("referenceB", "参照物终点")]
        let body: [(String, String)]
        switch feature.rawValue {
        case "SM01": body = [("vertex", "头顶"), ("ground", "地面")]
        case "SM08": body = [("shoulder", "\(side)肩点"), ("elbow", "\(side)肘点"), ("wrist", "\(side)腕点")]
        case "SM09": body = [("hip", "\(side)髋点"), ("knee", "\(side)膝点"), ("ankle", "\(side)踝点")]
        case "SR01": body = [("left", "身体左肩轮廓"), ("right", "身体右肩轮廓")]
        case "SR02": body = [("left", "左耳垂"), ("right", "右耳垂")]
        case "SR03": body = [("upperLeft", "腋下层画面左边界"), ("upperRight", "腋下层画面右边界"), ("waistLeft", "肚脐层画面左边界"), ("waistRight", "肚脐层画面右边界")]
        default: body = [("start", "待测起点"), ("end", "待测终点")]
        }
        return feature.rawValue == "SR02" ? body : reference + body
    }
    private var hasModel: Bool { ["SM08", "SM09"].contains(feature.rawValue) }
    private var needsLevel: Bool { ["SM01", "SR01", "SR02", "SR03"].contains(feature.rawValue) }
    private var length: Double? { Double(referenceLength) }
    private var draft: StaticMeasurementInput? {
        guard referenceLength.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || length != nil else { return nil }
        return try? StaticPhotoGeometry.input(feature: feature, points: points, referenceLength: length, samePlane: samePlane, corrected: corrected, level: level, side: side)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("导入照片，逐点确认")
                        .font(.title2.weight(.semibold))
                    Text("照片仅保存在本机。点选坐标与参照长度会随记录保存；本工具不自动校正镜头畸变。")
                        .font(.subheadline).foregroundStyle(.secondary)
                    let photoPickerTitle = image == nil ? "选择照片" : "更换照片"
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label(photoPickerTitle, systemImage: "photo")
                    }.buttonStyle(.bordered).accessibilityIdentifier("chooseStaticPhotoButton")
                    if ProcessInfo.processInfo.arguments.contains("--uitesting-photo") {
                        Button("载入测试标定图") { loadFixture() }.accessibilityIdentifier("loadPhotoFixtureButton")
                    }
                    if let image {
                        photoCanvas(image)
                        Picker("当前标点", selection: $selectedPoint) {
                            ForEach(pointLabels, id: \.0) { key, label in
                                Text("\(points[key] == nil ? "○" : "●") \(label)").tag(key)
                            }
                        }.pickerStyle(.menu).accessibilityIdentifier("photoPointPicker")
                        Button("清除当前测点") {
                            captureVersion = UUID(); detecting = false; confirmed = false
                            points.removeValue(forKey: selectedPoint)
                        }.disabled(points[selectedPoint] == nil)
                            .accessibilityIdentifier("clearPhotoPointButton")
                        if feature == .sm09 {
                            Text("髋点无法确认时可清除它，仅保留膝踝投影长度。")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Text("先选择测点，再点照片中的对应位置。修改上层或腰部左边界时，右边界会保持在同一水平线上。")
                            .font(.caption).foregroundStyle(.secondary)
                        if hasModel {
                            Picker("身体侧别", selection: $side) { Text("左侧").tag("左"); Text("右侧").tag("右") }
                                .pickerStyle(.segmented)
                                .onChange(of: side) { _, _ in
                                    captureVersion = UUID(); detecting = false
                                    points = points.filter { $0.key.hasPrefix("reference") }; confirmed = false; modelRevision = nil
                                }
                            Button {
                                detectPoints(image)
                            } label: {
                                Label(detecting ? "正在寻找关节点…" : "尝试自动标记关节点", systemImage: "figure.stand")
                            }.disabled(detecting).accessibilityIdentifier("detectBodyPointsButton")
                            Text("初标来自系统人体姿态模型。请逐点核对并修正；它给出的是投影点位，不是真实骨长。")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if feature.rawValue != "SR02" {
                            VStack(alignment: .leading, spacing: 12) {
                                TextField("参照物实长（cm）", text: $referenceLength)
                                    .keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
                                    .accessibilityIdentifier("photoReferenceLengthField")
                                if feature.rawValue != "SR02" {
                                    Text("留空时仅保留像素长度、比例或角度。厘米换算需要已校正照片与共面参照物。")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Toggle("参照物与测量部位位于同一平面", isOn: $samePlane)
                                    .accessibilityIdentifier("photoSamePlaneToggle")
                                Toggle("导入照片已做镜头畸变校正", isOn: $corrected)
                                    .accessibilityIdentifier("photoCorrectedToggle")
                            }
                        }
                        if needsLevel {
                            Toggle("照片的水平与竖直方向已经核对", isOn: $level)
                                .accessibilityIdentifier("photoLevelToggle")
                        }
                        Toggle("所有点位均已逐点复核", isOn: $confirmed)
                            .disabled(detecting)
                            .accessibilityIdentifier("photoConfirmedToggle")
                        if draft == nil { Text("请补齐对应测点并核对照片方向；填写参照长度后还需确认校正和共面条件。")
                            .font(.caption).foregroundStyle(.secondary) }
                        if let message { Text(message).font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("photoStatusMessage") }
                        Button("将标点用于计算", action: apply)
                            .buttonStyle(.borderedProminent)
                            .disabled(draft == nil || !confirmed || detecting)
                            .accessibilityIdentifier("applyPhotoPointsButton")
                    }
                }.padding(20).pageWidth()
            }
            .background(KaXTheme.background)
            .navigationTitle("照片标点")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() }.accessibilityIdentifier("cancelStaticPhotoButton") }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                        .accessibilityIdentifier("photoKeyboardDoneButton")
                }
            }
            .onChange(of: selectedPhoto) { _, item in
                captureVersion = UUID(); let version = captureVersion
                image = nil; detecting = false
                Task {
                    guard let data = try? await item?.loadTransferable(type: Data.self), let original = UIImage(data: data) else {
                        guard version == captureVersion else { return }
                        message = "无法读取这张照片，请重新选择。"; return
                    }
                    guard version == captureVersion else { return }
                    image = StaticPhotoFiles.normalized(original)
                    points = [:]; samePlane = false; corrected = false; level = false; confirmed = false
                    referenceLength = ""; modelRevision = nil; message = nil
                    selectedPoint = pointLabels[0].0
                }
            }
        }
    }

    private func photoCanvas(_ photo: UIImage) -> some View {
        GeometryReader { geometry in
            let displaySize = CGSize(width: geometry.size.width, height: geometry.size.width * photo.size.height / photo.size.width)
            Image(uiImage: photo).resizable().aspectRatio(contentMode: .fit)
                .overlay {
                    ZStack {
                        ForEach(pointLabels, id: \.0) { key, label in
                            if let point = points[key] {
                                VStack(spacing: 1) {
                                    Text(label).font(.caption2).padding(3).background(.regularMaterial, in: Capsule())
                                    Circle().fill(key == selectedPoint ? .orange : KaXTheme.accent).frame(width: 12, height: 12).overlay(Circle().stroke(.white, lineWidth: 2))
                                }
                                .position(x: point.x / photo.size.width * displaySize.width,
                                          y: (1 - point.y / photo.size.height) * displaySize.height - 12)
                                .accessibilityHidden(true)
                            }
                        }
                    }
                }
                .contentShape(Rectangle())
                .gesture(SpatialTapGesture().onEnded { tap in
                    guard var p = StaticPhotoGeometry.pointInImage(location: tap.location, displaySize: displaySize, imageSize: photo.size) else { return }
                    if feature.rawValue == "SR03" {
                        if selectedPoint == "upperRight", let left = points["upperLeft"] { p.y = left.y }
                        if selectedPoint == "waistRight", let left = points["waistLeft"] { p.y = left.y }
                        if selectedPoint == "upperLeft", let right = points["upperRight"] { points["upperRight"] = CGPoint(x: right.x, y: p.y) }
                        if selectedPoint == "waistLeft", let right = points["waistRight"] { points["waistRight"] = CGPoint(x: right.x, y: p.y) }
                    }
                    captureVersion = UUID(); detecting = false
                    points[selectedPoint] = p; confirmed = false
                    if let index = pointLabels.firstIndex(where: { $0.0 == selectedPoint }), index + 1 < pointLabels.count {
                        selectedPoint = pointLabels[index + 1].0
                    }
                })
                .accessibilityLabel("照片测量画布")
                .accessibilityIdentifier("staticPhotoCanvas")
        }.aspectRatio(photo.size.width / photo.size.height, contentMode: .fit)
    }

    private func apply() {
        guard var input = draft, let image else { return }
        do {
            input.text["imageID"] = try StaticPhotoFiles.save(image)
            input.text["imageWidth"] = String(Int(image.size.width))
            input.text["imageHeight"] = String(Int(image.size.height))
            input.text["pointSource"] = modelRevision == nil ? "手工标点并复核" : "系统模型初标后人工复核"
            input.text["modelRevision"] = modelRevision
            onApply(input); dismiss()
        } catch { message = error.localizedDescription }
    }

    private func detectPoints(_ photo: UIImage) {
        guard let data = photo.jpegData(compressionQuality: 1) else { return }
        detecting = true; message = nil; confirmed = false
        let version = captureVersion
        let isArm = feature.rawValue == "SM08", isLeft = side == "左"
        Task {
            do {
                let output = try await Task.detached(priority: .userInitiated) { () -> ([String: CGPoint], String) in
                    let request = VNDetectHumanBodyPoseRequest()
                    try VNImageRequestHandler(data: data, orientation: .up).perform([request])
                    guard let observations = request.results, observations.count == 1, let body = observations.first else {
                        throw StaticPhotoError.message("请使用仅有一人的清晰照片；也可以逐点手工标记。")
                    }
                    let names: [(String, VNHumanBodyPoseObservation.JointName)] = isArm
                        ? [("shoulder", isLeft ? .leftShoulder : .rightShoulder), ("elbow", isLeft ? .leftElbow : .rightElbow), ("wrist", isLeft ? .leftWrist : .rightWrist)]
                        : [("hip", isLeft ? .leftHip : .rightHip), ("knee", isLeft ? .leftKnee : .rightKnee), ("ankle", isLeft ? .leftAnkle : .rightAnkle)]
                    var found: [String: CGPoint] = [:]
                    for (key, name) in names {
                        let point = try body.recognizedPoint(name)
                        // An engineering display filter, not a validated measurement confidence threshold.
                        if point.confidence >= 0.3 { found[key] = point.location }
                    }
                    guard !found.isEmpty else { throw StaticPhotoError.message("没有可复核的关节点，请改用手工标点。") }
                    return (found, "Apple Vision Body Pose revision \(request.revision)")
                }.value
                guard version == captureVersion else { return }
                confirmed = false
                points = points.filter { $0.key.hasPrefix("reference") }
                for (key, p) in output.0 { points[key] = CGPoint(x: p.x * photo.size.width, y: p.y * photo.size.height) }
                modelRevision = output.1
                message = output.0.count == 3 ? "已标出三个候选点，请逐点检查位置。" : "只找到部分候选点，请补齐并逐点检查。"
            } catch {
                guard version == captureVersion else { return }
                message = (error as? StaticPhotoError)?.localizedDescription
                    ?? "自动标点当前不可用，请改用手工标点。"
            }
            detecting = false
        }
    }

    private func loadFixture() {
        captureVersion = UUID(); detecting = false; modelRevision = nil
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 800))
        image = StaticPhotoFiles.normalized(renderer.image { context in
            UIColor.systemGray6.setFill(); context.fill(CGRect(x: 0, y: 0, width: 600, height: 800))
            UIColor.systemGreen.setStroke()
            let path = UIBezierPath(); path.move(to: CGPoint(x: 100, y: 100)); path.addLine(to: CGPoint(x: 100, y: 300)); path.lineWidth = 4; path.stroke()
        })
        points = [:]; selectedPoint = pointLabels[0].0
        referenceLength = ""; samePlane = false; corrected = false; level = false; confirmed = false
        message = "测试标定图，仅用于自动化测试。"
    }
}
