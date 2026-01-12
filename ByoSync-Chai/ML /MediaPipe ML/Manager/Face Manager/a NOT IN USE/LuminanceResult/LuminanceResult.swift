//import Foundation
//internal import AVFoundation
//import CoreGraphics
//
//enum LuminanceStatus: String {
//    case tooDark = "too_dark"
//    case tooBright = "too_bright"
//    case uneven = "uneven"
//    case good = "good"
//}
//
//struct LuminanceResult: Equatable {
//    let score: Float              // 0..1
//    let status: LuminanceStatus
//    let medianLuminance: Float    // 0..255
//    let dynamicRange: Float       // p95 - p5 (0..255)
//    let clippedDarkPct: Float     // 0..1
//    let clippedBrightPct: Float   // 0..1
//}
//
//extension FaceManager {
//
//    /// Clamp ROI to pixel buffer bounds and return integral rect.
//    private func clampROI(_ roi: CGRect?, width: Int, height: Int) -> CGRect {
//        let full = CGRect(x: 0, y: 0, width: width, height: height)
//        guard let roi else { return full.integral }
//        return roi.intersection(full).integral
//    }
//
//    /// Histogram-based luminance metrics, matching your Python logic (BT.709 weights).
//    /// Assumes pixelBuffer format is 32BGRA (your setup already requests this). :contentReference[oaicite:3]{index=3}
//    func computeLuminance(
//        in pixelBuffer: CVPixelBuffer,
//        roi: CGRect? = nil,
//        downsampleStride: Int = 2   // downsample for speed; set 1 for full-res
//    ) -> LuminanceResult? {
//
//        let width = CVPixelBufferGetWidth(pixelBuffer)
//        let height = CVPixelBufferGetHeight(pixelBuffer)
//
//        let format = CVPixelBufferGetPixelFormatType(pixelBuffer)
//        guard format == kCVPixelFormatType_32BGRA else {
//            // If this hits, your capture pipeline isn't delivering BGRA as expected.
//            return nil
//        }
//
//        let r = clampROI(roi, width: width, height: height)
//        if r.isNull || r.width <= 1 || r.height <= 1 { return nil }
//
//        let sx = max(1, downsampleStride)
//        let sy = max(1, downsampleStride)
//
//        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
//        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
//
//        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
//        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
//
//        var hist = [Int](repeating: 0, count: 256)
//        var total = 0
//        var dark = 0
//        var bright = 0
//
//        let x0 = Int(r.minX), x1 = Int(r.maxX)
//        let y0 = Int(r.minY), y1 = Int(r.maxY)
//
//        for y in stride(from: y0, to: y1, by: sy) {
//            let rowPtr = base.advanced(by: y * bytesPerRow)
//            for x in stride(from: x0, to: x1, by: sx) {
//                // BGRA: [B, G, R, A]
//                let p = rowPtr.advanced(by: x * 4).assumingMemoryBound(to: UInt8.self)
//                let b = Float(p[0])
//                let g = Float(p[1])
//                let rr = Float(p[2])
//
//                // ITU-R BT.709 luminance
//                let yLum = 0.2126 * rr + 0.7152 * g + 0.0722 * b
//
//                var bin = Int(yLum.rounded())
//                if bin < 0 { bin = 0 }
//                if bin > 255 { bin = 255 }
//
//                hist[bin] += 1
//                total += 1
//
//                if bin < 10 { dark += 1 }
//                if bin > 245 { bright += 1 }
//            }
//        }
//
//        guard total > 0 else { return nil }
//
//        @inline(__always)
//        func percentileBin(_ q: Float) -> Float {
//            let target = max(0, min(total - 1, Int((Float(total - 1) * q).rounded())))
//            var cum = 0
//            for i in 0..<256 {
//                cum += hist[i]
//                if cum > target { return Float(i) }
//            }
//            return 255
//        }
//
//        let p5 = percentileBin(0.05)
//        let p50 = percentileBin(0.50)
//        let p95 = percentileBin(0.95)
//
//        let clippedDarkPct = Float(dark) / Float(total)
//        let clippedBrightPct = Float(bright) / Float(total)
//
//        // Scores (match Python)
//        let medianScore = max(0, min(1, 1.0 - abs(p50 - 127.5) / 127.5))
//        let dynamicRangeNorm = (p95 - p5) / 255.0
//        let rangeScore = min(dynamicRangeNorm / 0.7, 1.0)
//        let clippingPenalty = (clippedDarkPct + clippedBrightPct) * 0.5
//
//        var finalScore = (medianScore * 0.6 + rangeScore * 0.4) * (1 - clippingPenalty)
//        finalScore = max(0, min(1, finalScore))
//
//        let status: LuminanceStatus
//        if p50 < 70 {
//            status = .tooDark
//        } else if p50 > 200 {
//            status = .tooBright
//        } else if clippedDarkPct > 0.1 || clippedBrightPct > 0.1 {
//            status = .uneven
//        } else {
//            status = .good
//        }
//
//        return LuminanceResult(
//            score: finalScore,
//            status: status,
//            medianLuminance: p50,
//            dynamicRange: (p95 - p5),
//            clippedDarkPct: clippedDarkPct,
//            clippedBrightPct: clippedBrightPct
//        )
//    }
//
//    /// Returns 4 screen-space corners for a pixel-space rect.
//    /// Order: TL, TR, BR, BL
//    func screenQuad(forPixelRect r: CGRect) -> [CGPoint] {
//        let camW = imageSize.width
//        let camH = imageSize.height
//        guard camW > 0, camH > 0 else { return [] }
//
//        let tl = cameraPointToScreenPoint(x: r.minX, y: r.minY, cameraWidth: camW, cameraHeight: camH)
//        let tr = cameraPointToScreenPoint(x: r.maxX, y: r.minY, cameraWidth: camW, cameraHeight: camH)
//        let br = cameraPointToScreenPoint(x: r.maxX, y: r.maxY, cameraWidth: camW, cameraHeight: camH)
//        let bl = cameraPointToScreenPoint(x: r.minX, y: r.maxY, cameraWidth: camW, cameraHeight: camH)
//        return [tl, tr, br, bl]
//    }
//
//    /// One-call helper: compute luminance on the face ROI (faceBoundingBox) and return its screen quad.
//    /// Call this after `calculateFaceBoundingBox()` so `faceBoundingBox` is ready. :contentReference[oaicite:4]{index=4}
//    func computeFaceROILuminanceAndQuad(downsampleStride: Int = 2) -> (LuminanceResult, [CGPoint], CGRect)? {
//        guard let pb = latestPixelBuffer else { return nil }                     // set in captureOutput :contentReference[oaicite:5]{index=5}
//        guard let roi = faceBoundingBox else { return nil }                       // pixel rect :contentReference[oaicite:6]{index=6}
//        guard let lum = computeLuminance(in: pb, roi: roi, downsampleStride: downsampleStride) else { return nil }
//        let quad = screenQuad(forPixelRect: roi)
//        return (lum, quad, roi)
//    }
//}
