import SwiftUI

struct DirectionalGuidanceOverlay: View {
    @ObservedObject var faceManager: FaceManager

    // Android distance band
    private let IOD_MIN: Float = 0.30
    private let IOD_MAX: Float = 0.31

    // Nose centering tolerance in normalized space (should match updateNoseTipCenterStatusFromCalcCoords)
    private let NOSE_TOL: Float = 0.20

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 1) Distance guidance (ONLY when IOD invalid)
                if !faceManager.iodIsValid {
                    ambientGuidanceLayer
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }

                // 2) Arrows (ONLY when IOD valid and we still need alignment)
                if faceManager.iodIsValid && !allConditionsMet {
                    arrowGuidanceInsideOval(in: geometry.size)
                        .transition(.opacity)
                }

                // 2b) Optional small prompt if nose is centered but pose is not stable
                if faceManager.iodIsValid && faceManager.isNoseTipCentered && !faceManager.isHeadPoseStable() {
                    holdSteadyPrompt
                        .transition(.opacity)
                }

                // 3) Success state
                if allConditionsMet {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            successCelebration
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.85).combined(with: .opacity),
                                    removal: .opacity
                                ))
                            Spacer()
                        }
                        Spacer()
                    }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: allConditionsMet)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: faceManager.iodIsValid)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Gates (IOD valid + nose centered + pose stable)

    private var allConditionsMet: Bool {
        faceManager.iodIsValid &&
        faceManager.isNoseTipCentered &&
        faceManager.isHeadPoseStable()
    }

    // MARK: - Position + Distance Guidance (Android-style; now driven by nose tip)

    private var positionGuidance: PositionGuidance {
        var guidance = PositionGuidance()

        // Need the target center for arrow placement, but direction comes from nose tip
        guard !faceManager.TransalatedScaledFaceOvalCoordinates.isEmpty else {
            return guidance
        }

        // 1) Horizontal/vertical: use nose tip in NormalizedPoints (index 4), centered at (0,0)
        //    Important: your UI mapping is y = cy - normY*scale, so:
        //      normY > 0 => nose is ABOVE center => user should move DOWN
        //      normY < 0 => nose is BELOW center => user should move UP
        if faceManager.NormalizedPoints.count > 4 {
            let nose = faceManager.NormalizedPoints[4]
            let nx = nose.x
            let ny = nose.y

            // Horizontal (same convention as your old deltaX logic)
            if nx > NOSE_TOL {
                guidance.horizontal = .left
                guidance.horizontalIntensity = intensity(abs(nx) - NOSE_TOL, denom: 0.6)
            } else if nx < -NOSE_TOL {
                guidance.horizontal = .right
                guidance.horizontalIntensity = intensity(abs(nx) - NOSE_TOL, denom: 0.6)
            }

            // Vertical (note the inverted mapping explained above)
            if ny > NOSE_TOL {
                guidance.vertical = .down
                guidance.verticalIntensity = intensity(abs(ny) - NOSE_TOL, denom: 0.6)
            } else if ny < -NOSE_TOL {
                guidance.vertical = .up
                guidance.verticalIntensity = intensity(abs(ny) - NOSE_TOL, denom: 0.6)
            }
        }

        // 2) Distance: from IOD gate
        switch faceManager.iodGuidance {
        case .moveCloser:
            guidance.distance = .closer
            guidance.distanceIntensity = CGFloat(min((IOD_MIN - faceManager.iodNormalized) / 0.02, 1.0))
        case .moveFarther:
            guidance.distance = .farther
            guidance.distanceIntensity = CGFloat(min((faceManager.iodNormalized - IOD_MAX) / 0.02, 1.0))
        case .ok:
            guidance.distance = .perfect
            guidance.distanceIntensity = 0
        case .noFace:
            guidance.distance = .perfect
            guidance.distanceIntensity = 0
        }

        return guidance
    }

    private func intensity(_ value: Float, denom: Float) -> CGFloat {
        guard denom > 1e-6 else { return 0 }
        return CGFloat(min(max(value / denom, 0), 1.0))
    }

    private func calculateCenter(from points: [(x: CGFloat, y: CGFloat)]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        let sumX = points.reduce(0.0) { $0 + $1.x }
        let sumY = points.reduce(0.0) { $0 + $1.y }
        return CGPoint(x: sumX / CGFloat(points.count), y: sumY / CGFloat(points.count))
    }

    // MARK: - Arrow Guidance Inside Oval

    private func arrowGuidanceInsideOval(in size: CGSize) -> some View {
        let guidance = positionGuidance
        let targetCenter = calculateCenter(from: faceManager.TransalatedScaledFaceOvalCoordinates)

        return ZStack {
            // Left arrow
            if guidance.horizontal == .left {
                AsyncImage(url: URL(string: "https://res.cloudinary.com/da2cxcqup/image/upload/v1764256539/rollleft_jm0ady.png")) { image in
                    image.resizable().aspectRatio(contentMode: .fit)
                } placeholder: { ProgressView() }
                    .frame(width: 80, height: 80)
                    .position(x: targetCenter.x - 80, y: targetCenter.y)
                    .modifier(DirectionalPulseModifier(intensity: guidance.horizontalIntensity))
            }

            // Right arrow
            if guidance.horizontal == .right {
                AsyncImage(url: URL(string: "https://res.cloudinary.com/da2cxcqup/image/upload/v1764256007/rollright_arpuqd.png")) { image in
                    image.resizable().aspectRatio(contentMode: .fit)
                } placeholder: { ProgressView() }
                    .frame(width: 80, height: 80)
                    .position(x: targetCenter.x + 80, y: targetCenter.y)
                    .modifier(DirectionalPulseModifier(intensity: guidance.horizontalIntensity))
            }

            // Up arrow
            if guidance.vertical == .up {
                AsyncImage(url: URL(string: "https://res.cloudinary.com/da2cxcqup/image/upload/v1764253847/up_xeoewe.png")) { image in
                    image.resizable().aspectRatio(contentMode: .fit)
                } placeholder: { ProgressView() }
                    .frame(width: 80, height: 80)
                    .position(x: targetCenter.x, y: targetCenter.y - 100)
                    .modifier(DirectionalPulseModifier(intensity: guidance.verticalIntensity))
            }

            // Down arrow
            if guidance.vertical == .down {
                AsyncImage(url: URL(string: "https://res.cloudinary.com/da2cxcqup/image/upload/v1764253847/down_ijhlr4.png")) { image in
                    image.resizable().aspectRatio(contentMode: .fit)
                } placeholder: { ProgressView() }
                    .frame(width: 80, height: 80)
                    .position(x: targetCenter.x, y: targetCenter.y + 100)
                    .modifier(DirectionalPulseModifier(intensity: guidance.verticalIntensity))
            }
        }
    }

    // MARK: - Distance Guidance Layer (only when IOD invalid)

    private var ambientGuidanceLayer: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 80)
            directionalGuidanceZone
                .frame(maxHeight: .infinity)
        }
    }

    private var directionalGuidanceZone: some View {
        let guidance = positionGuidance
        return ZStack {
            if guidance.distance != .perfect {
                distanceIndicator(guidance: guidance)
            }
        }
    }

    private func distanceIndicator(guidance: PositionGuidance) -> some View {
        HStack {
            Spacer()
            VStack(spacing: 12) {
                Text(guidance.distance == .closer ? "Move Closer" : "Move Back")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.orange.opacity(0.3),
                                                Color.orange.opacity(0.15)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.orange.opacity(0.4), lineWidth: 1)
                            )
                    )
                    .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
            }
            Spacer()
        }
    }

    // MARK: - Pose prompt (optional)

    private var holdSteadyPrompt: some View {
        VStack {
            Spacer().frame(height: 110)
            Text("Hold your head steady")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                )
            Spacer()
        }
    }

    // MARK: - Success Celebration

    private var successCelebration: some View {
        VStack {
            Spacer()

            VStack(spacing: 8) {
                Text("Perfect Position!")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Hold steady while capturing")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.green.opacity(0.2),
                                        Color.green.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.green.opacity(0.5),
                                        Color.green.opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
            )
            .shadow(color: .green.opacity(0.25), radius: 20, y: 8)

            Spacer().frame(height: 200)
        }
    }
}

// MARK: - Supporting Types

struct PositionGuidance {
    var horizontal: Direction = .center
    var vertical: Direction = .center
    var distance: Distance = .perfect
    var horizontalIntensity: CGFloat = 0
    var verticalIntensity: CGFloat = 0
    var distanceIntensity: CGFloat = 0
}

enum Direction { case left, right, up, down, center }
enum Distance { case closer, farther, perfect }

// MARK: - Animation Modifiers

struct DirectionalPulseModifier: ViewModifier {
    let intensity: CGFloat
    @State private var animationPhase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .scaleEffect(1.0 + (intensity * 0.08 * sin(animationPhase)))
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.8 + Double(1.0 - intensity) * 0.4)
                        .repeatForever(autoreverses: false)
                ) {
                    animationPhase = .pi * 2
                }
            }
    }
}
