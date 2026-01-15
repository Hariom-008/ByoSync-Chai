import SwiftUI

struct TargetFaceOvalOverlay: View {
    @ObservedObject var faceManager: FaceManager

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                // ✅ Static geometric oval (matches Android logic)
                let cx = size.width / 2.0
                let cy = size.height * 0.45  // 45% from top (like Android)
                
                var ovalWidth = size.width * 0.75   // 75% of screen width
                var ovalHeight = size.height * 0.40  // 40% of screen height
                if UIDevice.current.userInterfaceIdiom == .pad{
                    let temp = ovalWidth
                    ovalWidth = ovalHeight
                    ovalHeight = temp
                }
                
                
                let ovalRect = CGRect(
                    x: cx - ovalWidth / 2.0,
                    y: cy - ovalHeight / 2.0,
                    width: ovalWidth,
                    height: ovalHeight
                )
                
                // Create oval path
                let ovalPath = Path(ellipseIn: ovalRect)
                
                // --- 1) Black/White outside area (mask) ---
                var fullScreenPath = Path()
                fullScreenPath.addRect(CGRect(origin: .zero, size: size))
                
                // Create cutout by combining paths
                var maskPath = Path()
                maskPath.addPath(fullScreenPath)
                maskPath.addPath(ovalPath)
                
                // Fill outside area with semi-transparent white/black
                context.fill(
                    maskPath,
                    with: .color(Color.white.opacity(0.85)),
                    style: FillStyle(eoFill: true)  // Even-odd fill creates the cutout
                )
                
                // --- 2) Oval border color based on alignment ---
                let isAligned = faceManager.faceisInsideFaceOval && faceManager.isHeadPoseStable()
                
                let borderColor: Color
                if !faceManager.iodIsValid {
                    borderColor = Color.red.opacity(0.9)
                } else if isAligned {
                    borderColor = Color(red: 76/255, green: 175/255, blue: 80/255).opacity(0.9)  // #4CAF50
                } else {
                    borderColor = Color.yellow.opacity(0.9)
                }
                
                // Draw oval border
                context.stroke(
                    ovalPath,
                    with: .color(borderColor),
                    style: StrokeStyle(lineWidth: 8.0, lineCap: .round, lineJoin: .round)
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
