import Foundation
import CoreGraphics

enum StaticPhotoError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let message) = self { return message }; return nil }
}

enum StaticPhotoGeometry {
    static func pointInImage(location: CGPoint, displaySize: CGSize, imageSize: CGSize) -> CGPoint? {
        guard displaySize.width > 0, displaySize.height > 0, imageSize.width > 0, imageSize.height > 0,
              location.x >= 0, location.y >= 0, location.x <= displaySize.width, location.y <= displaySize.height else { return nil }
        return CGPoint(x: location.x / displaySize.width * imageSize.width,
                       y: (1 - location.y / displaySize.height) * imageSize.height)
    }

    static func input(feature: StaticFeatureID, points: [String: CGPoint], referenceLength: Double?,
                      samePlane: Bool, corrected: Bool, level: Bool, side: String) throws -> StaticMeasurementInput {
        func point(_ key: String) throws -> CGPoint {
            guard let p = points[key], p.x.isFinite, p.y.isFinite else { throw StaticPhotoError.message("请完成所有测量点的标记。") }
            return p
        }
        let requiresLevel = ["SM01", "SR01", "SR02", "SR03"].contains(feature.rawValue)
        if requiresLevel && !level { throw StaticPhotoError.message("请核对照片的水平与竖直方向。") }
        var scale: Double?
        var refPixels: Double?
        if let length = referenceLength {
            guard length.isFinite, length > 0 else { throw StaticPhotoError.message("请填写参照物的实际长度。") }
            let a = try point("referenceA"), b = try point("referenceB")
            let pixels = hypot(a.x - b.x, a.y - b.y)
            guard pixels >= 1 else { throw StaticPhotoError.message("参照物两端不能重合。") }
            guard samePlane, corrected else { throw StaticPhotoError.message("厘米换算需要共面参照物及已校正畸变的照片；角度项目可清空参照长度，仅记录角度。") }
            refPixels = pixels; scale = length / pixels
        }
        var values: [String: Double] = [:]
        func add(_ key: String, x: String, y: String) throws {
            let p = try point(key); values[x] = p.x; values[y] = p.y
        }
        switch feature.rawValue {
        case "SM01":
            values = ["vertexY": try point("vertex").y, "groundY": try point("ground").y]
            values["referenceLengthCM"] = referenceLength; values["referencePixels"] = refPixels
        case "Q01":
            let a = try point("start"), b = try point("end")
            values = ["distancePixels": hypot(a.x - b.x, a.y - b.y)]
            values["referenceLengthCM"] = referenceLength; values["referencePixels"] = refPixels
        case "SM08":
            try add("shoulder", x: "shoulderX", y: "shoulderY")
            try add("elbow", x: "elbowX", y: "elbowY")
            try add("wrist", x: "wristX", y: "wristY")
            values["scaleCMPerPixel"] = scale
        case "SM09":
            if points["hip"] != nil { try add("hip", x: "hipX", y: "hipY") }
            try add("knee", x: "kneeX", y: "kneeY")
            try add("ankle", x: "ankleX", y: "ankleY")
            values["scaleCMPerPixel"] = scale
        case "SR01":
            try add("left", x: "leftX", y: "leftY"); try add("right", x: "rightX", y: "rightY")
            values["scaleCMPerPixel"] = scale
        case "SR02":
            try add("left", x: "leftEarX", y: "leftEarY"); try add("right", x: "rightEarX", y: "rightEarY")
        case "SR03":
            let ul = try point("upperLeft"), ur = try point("upperRight")
            let wl = try point("waistLeft"), wr = try point("waistRight")
            guard abs(ul.y - ur.y) < 0.001, abs(wl.y - wr.y) < 0.001 else { throw StaticPhotoError.message("同一层面的轮廓点须保持水平。") }
            values = ["upperLeftX": ul.x, "upperRightX": ur.x, "waistLeftX": wl.x, "waistRightX": wr.x,
                      "upperY": ul.y, "waistY": wl.y]
            values["scaleCMPerPixel"] = scale
        default: throw StaticPhotoError.message("此项目请使用对应的尺寸录入。")
        }
        var input = StaticMeasurementInput(values: values)
        input.text = ["inputMode": "photo", "side": side, "pointSource": "手工标点",
                      "samePlaneConfirmed": String(samePlane), "levelConfirmed": String(level),
                      "calibrationMethod": scale == nil ? "未使用厘米标定" : "已校正照片中的同平面长度参照",
                      "coordinateConvention": feature == .sr03 ? "x向右，y向上；轮廓左右按画面方向" : "x向右，y向上；左右关节或耳肩标点指身体侧别"]
        input.metadata["calibrationStatus"] = scale == nil ? "仅像素" : "已校正且共面"
        input.text["calibrationStatus"] = input.metadata["calibrationStatus"]
        let encodedPoints = points.mapValues { [Double($0.x), Double($0.y)] }
        if let data = try? JSONEncoder().encode(encodedPoints) { input.text["photoPointsJSON"] = String(data: data, encoding: .utf8) }
        return input
    }
}
