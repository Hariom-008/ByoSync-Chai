import SwiftUI

struct DirectionalGuidanceOverlay: View {
    @ObservedObject var faceManager: FaceManager

    // MARK: - Thresholds
    private let IOD_NORM_MAX: Float = 0.22

    // If you want different stability thresholds per phase, tune here.
    private let REG_CENTER_PITCH_THR: Float = 0.12
    private let REG_CENTER_YAW_THR:   Float = 0.12
    private let REG_CENTER_ROLL_THR:  Float = 0.05

    private let MOVE_PITCH_THR: Float = 0.12
    private let MOVE_YAW_THR:   Float = 0.12
    private let MOVE_ROLL_THR:  Float = 0.05

    private let VER_PITCH_THR: Float = 0.12
    private let VER_YAW_THR:   Float = 0.12
    private let VER_ROLL_THR:  Float = 0.05

    var body: some View {
        ZStack {
            switch faceManager.faceAuthManager.currentMode {
            case .registration:
                registrationOverlay
            case .verification:
                verificationOverlay
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Registration

    private var registrationOverlay: some View {
        ZStack {
            switch faceManager.registrationPhase {

            case .centerCollecting:
                registrationCenterTrackingOverlay

            case .movementCollecting:
                registrationMovementTrackingOverlay

            case .done:
                stablePill(text: "Processing…")
            }
        }
    }

    /// Phase 1: centre tracking gates
    /// iodIsValid && iodNormalized<=0.31 && headPoseStable && faceInsideOval
    private var registrationCenterTrackingOverlay: some View {
        let iodOk = faceManager.iodIsValid
        let iodNormOk = faceManager.iodNormalized <= IOD_NORM_MAX
        let stable = faceManager.isPoseStable(
            pitchThr: REG_CENTER_PITCH_THR,
            yawThr: REG_CENTER_YAW_THR,
            rollThr: REG_CENTER_ROLL_THR
        )
        let inside = faceManager.faceisInsideFaceOval

        let allOk = iodOk && iodNormOk && stable && inside

        return ZStack {
            topPill(text: "Hold steady • \(faceManager.centerFramesCount)/60")

            VStack(spacing: 10) {
                Spacer().frame(height: 170)

                VStack(spacing: 10) {
                    gateRow(ok: iodOk && iodNormOk,
                            okText: "✓ Distance OK",
                            badText: iodBadText(iodOk: iodOk, iodNormOk: iodNormOk))

                    gateRow(ok: stable,
                            okText: "✓ Keep steady",
                            badText: "Hold steady")

                    gateRow(ok: inside,
                            okText: "✓ Face inside oval",
                            badText: "Fit your face inside the oval")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 18).fill(Color.black.opacity(0.65)))

                if allOk {
                    Text("Capturing… \(faceManager.centerFramesCount)/60")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                        .padding(.top, 6)
                }

                Spacer()
            }
        }
    }

    /// Phase 2: movement tracking gates
    /// isHeadPoseStable && faceInsideOval
    /// (NO direction UI, NO IOD guidance here)
    private var registrationMovementTrackingOverlay: some View {
        let stable = faceManager.isPoseStable(
            pitchThr: MOVE_PITCH_THR,
            yawThr: MOVE_YAW_THR,
            rollThr: MOVE_ROLL_THR
        )
        let inside = faceManager.faceisInsideFaceOval
        let allOk = stable && inside

        return ZStack {
            topPill(text: "Move naturally • \(faceManager.movementSecondsRemaining)s")

            VStack(spacing: 10) {
                Spacer().frame(height: 170)

                VStack(spacing: 10) {
                    gateRow(ok: stable,
                            okText: "✓ Keep steady",
                            badText: "Hold steady")

                    gateRow(ok: inside,
                            okText: "✓ Face inside oval",
                            badText: "Fit your face inside the oval")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 18).fill(Color.black.opacity(0.65)))

                if allOk {
                    Text("Capturing… \(faceManager.movementFramesCount)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                        .padding(.top, 6)
                }

                Spacer()
            }
        }
    }

    // MARK: - Verification

    /// Verification gates:
    /// iodIsValid && iodNormalized<=0.31 && headPoseStable && faceInsideOval
    private var verificationOverlay: some View {
        let iodOk = faceManager.iodIsValid
        let iodNormOk = faceManager.iodNormalized <= IOD_NORM_MAX
        let stable = faceManager.isPoseStable(
            pitchThr: VER_PITCH_THR,
            yawThr: VER_YAW_THR,
            rollThr: VER_ROLL_THR
        )
        let inside = faceManager.faceisInsideFaceOval

        let allOk = iodOk && iodNormOk && stable && inside

        return ZStack {
            topPill(text: "Align your face")

            VStack(spacing: 10) {
                Spacer().frame(height: 170)

                VStack(spacing: 10) {
                    gateRow(ok: iodOk && iodNormOk,
                            okText: "✓ Distance OK",
                            badText: iodBadText(iodOk: iodOk, iodNormOk: iodNormOk))

                    gateRow(ok: stable,
                            okText: "✓ Keep steady",
                            badText: "Hold steady")

                    gateRow(ok: inside,
                            okText: "✓ Face inside oval",
                            badText: "Fit your face inside the oval")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 18).fill(Color.black.opacity(0.65)))

                if allOk {
                    stablePill(text: "Capturing…")
                        .padding(.top, 6)
                }

                Spacer()
            }
        }
    }

    // MARK: - Gate Row UI

    @ViewBuilder
    private func gateRow(ok: Bool, okText: String, badText: String) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(ok ? Color.green : Color.red)
                .frame(width: 10, height: 10)

            Text(ok ? okText : badText)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white)

            Spacer()
        }
    }

    // MARK: - IOD Text Logic

    /// Combines your old iodGuidance + new iodNormalized<=0.31 rule.
    private func iodBadText(iodOk: Bool, iodNormOk: Bool) -> String {
        if !iodOk {
            // use your existing guidance wording
            return distanceText
        }
        // iodOk == true but iodNormalized too large -> face too small / too far
        if !iodNormOk {
            return "Move closer"
        }
        return distanceText
    }

    private var distanceText: String {
        switch faceManager.iodGuidance {
        case .moveCloser: return "Move closer"
        case .moveFarther: return "Move back"
        case .ok: return "Perfect distance"
        case .noFace: return "Position your face"
        }
    }

    // MARK: - Pills

    private func topPill(text: String) -> some View {
        VStack {
            Spacer().frame(height: 120)
            Text(text)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.65)))
            Spacer()
        }
    }

    private func stablePill(text: String) -> some View {
        VStack {
            Spacer().frame(height: 120)
            Text("✓ \(text)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 20).fill(Color.green.opacity(0.85)))
            Spacer()
        }
    }
}


// MARK: - Animated Arrow Component

struct AnimatedArrow: View {
    let imageName: String
    let alignment: Alignment
    let offset: CGPoint
    
    var body: some View {
        VStack {
            if alignment == .top || alignment == .topLeading || alignment == .topTrailing {
                Spacer().frame(height: offset.y)
            } else if alignment == .leading || alignment == .trailing {
                Spacer()
            }
            
            HStack {
                if alignment == .leading || alignment == .topLeading {
                    Spacer().frame(width: offset.x)
                } else if alignment == .trailing || alignment == .topTrailing || alignment == .bottom || alignment == .top {
                    Spacer()
                }
                
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .modifier(ArrowPulseModifier())
                
                if alignment == .trailing || alignment == .topTrailing {
                    Spacer().frame(width: -offset.x)
                } else if alignment == .leading || alignment == .topLeading || alignment == .bottom || alignment == .top {
                    Spacer()
                }
            }
            
            if alignment == .bottom {
                Spacer().frame(height: -offset.y)
            } else if alignment == .leading || alignment == .trailing {
                Spacer()
            }
        }
    }
}

// MARK: - Animation Modifiers

struct PulseOpacityModifier: ViewModifier {
    @State private var opacity: Double = 0.7
    
    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.6)
                    .repeatForever(autoreverses: true)
                ) {
                    opacity = 1.0
                }
            }
    }
}

struct ArrowPulseModifier: ViewModifier {
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0.7
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.7)
                    .repeatForever(autoreverses: true)
                ) {
                    scale = 1.1
                    opacity = 1.0
                }
            }
    }
}

struct GlowPulseModifier: ViewModifier {
    @State private var opacity: Double = 0.5
    
    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.8)
                    .repeatForever(autoreverses: true)
                ) {
                    opacity = 1.0
                }
            }
    }
}
