import SwiftUI

struct TargetFaceOvalOverlay: View {
    @ObservedObject var faceManager: FaceManager
    
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.0
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                // Calculate oval dimensions (matches Android logic)
                let cx = size.width / 2.0
                let cy = size.height * 0.45  // 45% from top
                
                var ovalWidth = size.width * 0.75   // 75% of screen width
                var ovalHeight = size.height * 0.40  // 40% of screen height
                
                // Swap for iPad
                if UIDevice.current.userInterfaceIdiom == .pad {
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
                
                // --- 1) Darkened outside area with cutout ---
                var fullScreenPath = Path()
                fullScreenPath.addRect(CGRect(origin: .zero, size: size))
                
                var maskPath = Path()
                maskPath.addPath(fullScreenPath)
                maskPath.addPath(ovalPath)
                
                // Fill outside area - lighter, less intrusive
                context.fill(
                    maskPath,
                    with: .color(Color.black.opacity(0.65)),
                    style: FillStyle(eoFill: true)
                )
                
                // --- 2) Border color based on state ---
                let isAligned = faceManager.faceisInsideFaceOval && faceManager.isHeadPoseStable()
                
                let borderColor: Color
                let shouldGlow: Bool
                
                if !faceManager.iodIsValid {
                    // Face not detected or distance very wrong
                    borderColor = Color.red.opacity(0.8)
                    shouldGlow = false
                  //  print("🔴 [Oval] No valid face detected")
                } else if isAligned {
                    // Perfect alignment - green with glow
                    borderColor = Color.green
                    shouldGlow = true
                  //  print("🟢 [Oval] Face aligned perfectly")
                } else {
                    // Detected but needs adjustment - yellow
                    borderColor = Color.yellow.opacity(0.9)
                    shouldGlow = false
                  //  print("🟡 [Oval] Face detected, needs alignment")
                }
                
                // --- 3) Draw main border ---
                context.stroke(
                    ovalPath,
                    with: .color(borderColor),
                    style: StrokeStyle(
                        lineWidth: shouldGlow ? 6.0 : 4.0,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                
                // --- 4) Draw outer glow when aligned ---
                if shouldGlow {
                    context.stroke(
                        ovalPath,
                        with: .color(borderColor.opacity(glowOpacity * 0.4)),
                        style: StrokeStyle(
                            lineWidth: 12.0,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                }
                
                // --- 5) Corner guides for better spatial awareness ---
                if !isAligned && faceManager.iodIsValid {
                    drawCornerGuides(
                        context: context,
                        rect: ovalRect,
                        color: borderColor
                    )
                }
            }
            .onChange(of: faceManager.faceisInsideFaceOval && faceManager.isHeadPoseStable()) { isAligned in
                if isAligned {
                    startGlowAnimation()
                    startPulseAnimation()
                } else {
                    stopAnimations()
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
    
    // MARK: - Helper Functions
    
    private func drawCornerGuides(context: GraphicsContext, rect: CGRect, color: Color) {
        let cornerLength: CGFloat = 30
        let cornerWidth: CGFloat = 3
        
        let corners = [
            // Top-left
            (CGPoint(x: rect.minX, y: rect.minY), [
                CGPoint(x: rect.minX + cornerLength, y: rect.minY),
                CGPoint(x: rect.minX, y: rect.minY + cornerLength)
            ]),
            // Top-right
            (CGPoint(x: rect.maxX, y: rect.minY), [
                CGPoint(x: rect.maxX - cornerLength, y: rect.minY),
                CGPoint(x: rect.maxX, y: rect.minY + cornerLength)
            ]),
            // Bottom-left
            (CGPoint(x: rect.minX, y: rect.maxY), [
                CGPoint(x: rect.minX + cornerLength, y: rect.maxY),
                CGPoint(x: rect.minX, y: rect.maxY - cornerLength)
            ]),
            // Bottom-right
            (CGPoint(x: rect.maxX, y: rect.maxY), [
                CGPoint(x: rect.maxX - cornerLength, y: rect.maxY),
                CGPoint(x: rect.maxX, y: rect.maxY - cornerLength)
            ])
        ]
        
        for (center, points) in corners {
            for point in points {
                var path = Path()
                path.move(to: center)
                path.addLine(to: point)
                
                context.stroke(
                    path,
                    with: .color(color.opacity(0.6)),
                    style: StrokeStyle(
                        lineWidth: cornerWidth,
                        lineCap: .round
                    )
                )
            }
        }
    }
    
    // MARK: - Animations
    
    private func startGlowAnimation() {
        withAnimation(
            .easeInOut(duration: 1.0)
            .repeatForever(autoreverses: true)
        ) {
            glowOpacity = 1.0
        }
    }
    
    private func startPulseAnimation() {
        withAnimation(
            .easeInOut(duration: 0.8)
            .repeatForever(autoreverses: true)
        ) {
            pulseScale = 1.02
        }
    }
    
    private func stopAnimations() {
        withAnimation(.easeOut(duration: 0.3)) {
            glowOpacity = 0.0
            pulseScale = 1.0
        }
    }
}
