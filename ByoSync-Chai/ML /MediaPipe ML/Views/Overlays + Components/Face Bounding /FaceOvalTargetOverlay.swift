import SwiftUI

struct TargetFaceOvalOverlay: View {
    @ObservedObject var faceManager: FaceManager

    var body: some View {
        Canvas { context, size in
            let pts = faceManager.TransalatedScaledFaceOvalCoordinates
            guard pts.count > 2 else { return }

            // --- Build oval path ---
            var oval = Path()
            oval.move(to: CGPoint(x: pts[0].x, y: pts[0].y))
            for i in 1..<pts.count {
                oval.addLine(to: CGPoint(x: pts[i].x, y: pts[i].y))
            }
            oval.closeSubpath()

            // --- 1) Black outside area only when IOD is less than equal to 0.31 ---
            if faceManager.iodNormalized <= 0.30 {
                // Make a "cutout" path: full screen rect + oval, then fill with even-odd
                var cutout = Path()
                cutout.addRect(CGRect(origin: .zero, size: size))
                cutout.addPath(oval)

                context.fill(
                    cutout,
                    with: .color(.black.opacity(0.65)),
                    style: FillStyle(eoFill: true) // even-odd => punches a hole for the oval
                )
            }

            // --- 2) Stroke oval (your existing logic) ---
            let isAligned = faceManager.faceisInsideFaceOval && faceManager.isHeadPoseStable()

            let strokeColor: Color
            if !faceManager.iodIsValid {
                strokeColor = .red.opacity(0.8)
            } else if isAligned {
                strokeColor = .green.opacity(0.85)
            } else {
                strokeColor = .yellow.opacity(0.85)
            }

            context.stroke(
                oval,
                with: .color(strokeColor),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
