import SwiftUI

struct DirectionalGuidanceOverlay: View {
    @ObservedObject var faceManager: FaceManager
    
    // MARK: - Thresholds
    private let IOD_NORM_MAX: Float = 0.30
    
    private let REG_CENTER_PITCH_THR: Float = 0.12
    private let REG_CENTER_YAW_THR: Float = 0.12
    private let REG_CENTER_ROLL_THR: Float = 0.05
    
    private let MOVE_PITCH_THR: Float = 0.12
    private let MOVE_YAW_THR: Float = 0.12
    private let MOVE_ROLL_THR: Float = 0.05
    
    private let VER_PITCH_THR: Float = 0.12
    private let VER_YAW_THR: Float = 0.12
    private let VER_ROLL_THR: Float = 0.05
    
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
                successIndicator(text: "Processing…")
            }
        }
    }
    
    // MARK: - Phase 1: Center Tracking
    
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
        
        print("📊 [Center] IOD:\(iodOk) Norm:\(iodNormOk) Stable:\(stable) Inside:\(inside)")
        print("   • Pitch: \(String(format: "%.3f", faceManager.Pitch)) Yaw: \(String(format: "%.3f", faceManager.Yaw)) Roll: \(String(format: "%.3f", faceManager.Roll))")
        
        return ZStack {
            // Show directional guidance arrows
            if !allOk {
                poseGuidanceArrows(
                    pitchThr: REG_CENTER_PITCH_THR,
                    yawThr: REG_CENTER_YAW_THR,
                    rollThr: REG_CENTER_ROLL_THR,
                    iodOk: iodOk,
                    iodNormOk: iodNormOk
                )
            }
            
            VStack(spacing: 0) {
                Spacer().frame(height: 100)
                
                if allOk {
                    capturingIndicator(
                        count: faceManager.centerFramesCount,
                        total: 60,
                        label: "Hold Steady"
                    )
                } else {
                    primaryGuidanceText(
                        iodOk: iodOk,
                        iodNormOk: iodNormOk,
                        stable: stable,
                        inside: inside,
                        pitchThr: REG_CENTER_PITCH_THR,
                        yawThr: REG_CENTER_YAW_THR,
                        rollThr: REG_CENTER_ROLL_THR
                    )
                }
                
                Spacer()
                
                // Progress bar
                progressBar(current: faceManager.centerFramesCount, total: 60)
                    .padding(.bottom, 100)
            }
        }
    }
    
    // MARK: - Phase 2: Movement Tracking
    
    private var registrationMovementTrackingOverlay: some View {
        let stable = faceManager.isPoseStable(
            pitchThr: MOVE_PITCH_THR,
            yawThr: MOVE_YAW_THR,
            rollThr: MOVE_ROLL_THR
        )
        let inside = faceManager.faceisInsideFaceOval
        let allOk = stable && inside
        
        print("🎭 [Movement] Stable:\(stable) Inside:\(inside) Frames:\(faceManager.movementFramesCount)")
        
        return ZStack {
            // Show arrows if not stable
            if !allOk && !stable {
                poseGuidanceArrows(
                    pitchThr: MOVE_PITCH_THR,
                    yawThr: MOVE_YAW_THR,
                    rollThr: MOVE_ROLL_THR,
                    iodOk: true,
                    iodNormOk: true
                )
            }
            
            VStack(spacing: 0) {
                Spacer().frame(height: 100)
                
                if allOk {
                    movementCaptureIndicator(
                        count: faceManager.movementFramesCount,
                        secondsRemaining: faceManager.movementSecondsRemaining
                    )
                } else {
                    simpleGuidance(
                        text: inside ? "Hold Steady" : "Keep Face in Frame",
                        icon: "face.smiling"
                    )
                }
                
                Spacer()
                
                // Timer
                movementTimer(seconds: faceManager.movementSecondsRemaining)
                    .padding(.bottom, 100)
            }
        }
    }
    
    // MARK: - Verification
    
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
        
//        print("🔐 [Verification] IOD:\(iodOk) Norm:\(iodNormOk) Stable:\(stable) Inside:\(inside)")
//        print("   • Pitch: \(String(format: "%.3f", faceManager.Pitch)) Yaw: \(String(format: "%.3f", faceManager.Yaw)) Roll: \(String(format: "%.3f", faceManager.Roll))")
        
        return ZStack {
            // Show directional guidance arrows
            if !allOk {
                poseGuidanceArrows(
                    pitchThr: VER_PITCH_THR,
                    yawThr: VER_YAW_THR,
                    rollThr: VER_ROLL_THR,
                    iodOk: iodOk,
                    iodNormOk: iodNormOk
                )
            }
            
            VStack(spacing: 0) {
                Spacer().frame(height: 100)
                
                if allOk {
                    successIndicator(text: "Verifying…")
                } else {
                    primaryGuidanceText(
                        iodOk: iodOk,
                        iodNormOk: iodNormOk,
                        stable: stable,
                        inside: inside,
                        pitchThr: VER_PITCH_THR,
                        yawThr: VER_YAW_THR,
                        rollThr: VER_ROLL_THR
                    )
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Pose-Based Guidance Arrows
    
    @ViewBuilder
    private func poseGuidanceArrows(
        pitchThr: Float,
        yawThr: Float,
        rollThr: Float,
        iodOk: Bool,
        iodNormOk: Bool
    ) -> some View {
        ZStack {
            // Priority 1: Distance (IOD) - Most critical
            if !iodOk || !iodNormOk {
                distanceArrows(iodOk: iodOk, iodNormOk: iodNormOk)
            }
            // Priority 2: Head Rotation (Roll) - Second most important
            else if abs(faceManager.Roll) > rollThr {
                rollArrows(rollThr: rollThr)
            }
            // Priority 3: Yaw (Left/Right turn)
            else if abs(faceManager.Yaw) > yawThr {
                yawArrows(yawThr: yawThr)
            }
            // Priority 4: Pitch (Up/Down tilt)
            else if abs(faceManager.Pitch) > pitchThr {
                pitchArrows(pitchThr: pitchThr)
            }
        }
    }
    
    // Distance guidance (IOD-based)
    @ViewBuilder
    private func distanceArrows(iodOk: Bool, iodNormOk: Bool) -> some View {
        ZStack {
            if !iodOk {
                // Use IOD guidance from FaceManager
                switch faceManager.iodGuidance {
                case .moveCloser:
                    DirectionalArrow(
                        imageName: "up_arrow",
                        position: .bottom,
                        message: "Move Closer"
                    )
                case .moveFarther:
                    DirectionalArrow(
                        imageName: "down_arrow",
                        position: .top,
                        message: "Move Back"
                    )
                default:
                    EmptyView()
                }
            } else if !iodNormOk {
                // Face too far (iodNormalized > 0.31)
                DirectionalArrow(
                    imageName: "up_arrow",
                    position: .bottom,
                    message: "Move Closer"
                )
            }
        }
    }
    
    // Roll guidance (head tilt left/right)
    @ViewBuilder
    private func rollArrows(rollThr: Float) -> some View {
        let roll = faceManager.Roll
        
      //  print("🔄 [Roll] Value: \(String(format: "%.3f", roll)) | Threshold: ±\(rollThr)")
        
        if roll > rollThr {
            // Head tilted right → show left rotation arrow
            DirectionalArrow(
                imageName: "round_left_arrow",
                position: .center,
                message: "Straighten Head"
            )
        } else if roll < -rollThr {
            // Head tilted left → show right rotation arrow
            DirectionalArrow(
                imageName: "round_right_arrow",
                position: .center,
                message: "Straighten Head"
            )
        }
    }
    
    // Yaw guidance (face turn left/right)
    @ViewBuilder
    private func yawArrows(yawThr: Float) -> some View {
        let yaw = faceManager.Yaw
        
       // print("↔️ [Yaw] Value: \(String(format: "%.3f", yaw)) | Threshold: ±\(yawThr)")
        
        if yaw > yawThr {
            // Face turned right → show left arrow
            DirectionalArrow(
                imageName: "left_arrow",
                position: .right,
                message: "Turn Left"
            )
        } else if yaw < -yawThr {
            // Face turned left → show right arrow
            DirectionalArrow(
                imageName: "right_arrow",
                position: .left,
                message: "Turn Right"
            )
        }
    }
    
    // Pitch guidance (face tilt up/down)
    @ViewBuilder
    private func pitchArrows(pitchThr: Float) -> some View {
        let pitch = faceManager.Pitch
        
       // print("↕️ [Pitch] Value: \(String(format: "%.3f", pitch)) | Threshold: ±\(pitchThr)")
        
        if pitch > pitchThr {
            // Looking down → show up arrow
            DirectionalArrow(
                imageName: "up_arrow",
                position: .bottom,
                message: "Look Up"
            )
        } else if pitch < -pitchThr {
            // Looking up → show down arrow
            DirectionalArrow(
                imageName: "down_arrow",
                position: .top,
                message: "Look Down"
            )
        }
    }
    
    // MARK: - Primary Guidance Text
    
    @ViewBuilder
    private func primaryGuidanceText(
        iodOk: Bool,
        iodNormOk: Bool,
        stable: Bool,
        inside: Bool,
        pitchThr: Float,
        yawThr: Float,
        rollThr: Float
    ) -> some View {
        VStack(spacing: 12) {
            // Priority: Distance > Roll > Yaw > Pitch > Position
            if !iodOk || !iodNormOk {
                guidancePill(
                    text: getDistanceGuidance(iodOk: iodOk, iodNormOk: iodNormOk),
                    icon: "arrow.up.and.down.circle.fill",
                    color: .orange
                )
            } else if !inside {
                guidancePill(
                    text: "Center Your Face",
                    icon: "circle.dashed",
                    color: .yellow
                )
            } else if abs(faceManager.Roll) > rollThr {
                guidancePill(
                    text: "Straighten Your Head",
                    icon: "rotate.3d",
                    color: .blue
                )
            } else if abs(faceManager.Yaw) > yawThr {
                guidancePill(
                    text: faceManager.Yaw > 0 ? "Turn Left" : "Turn Right",
                    icon: "arrow.left.and.right",
                    color: .blue
                )
            } else if abs(faceManager.Pitch) > pitchThr {
                guidancePill(
                    text: faceManager.Pitch > 0 ? "Look Up" : "Look Down",
                    icon: "arrow.up.and.down",
                    color: .blue
                )
            } else {
                guidancePill(
                    text: "Hold Steady",
                    icon: "hand.raised.fill",
                    color: .blue
                )
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: stable)
    }
    
    // Simple guidance
    @ViewBuilder
    private func simpleGuidance(text: String, icon: String) -> some View {
        guidancePill(text: text, icon: icon, color: .blue)
    }
    
    // Guidance pill
    @ViewBuilder
    private func guidancePill(text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(color)
            
            Text(text)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(Color.black.opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .strokeBorder(color.opacity(0.3), lineWidth: 2)
                )
        )
    }
    
    // MARK: - Status Indicators
    
    @ViewBuilder
    private func capturingIndicator(count: Int, total: Int, label: String) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 6)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: CGFloat(count) / CGFloat(total))
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: count)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.green)
            }
            
            Text(label)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
            
            Text("\(count)/\(total)")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(Color.black.opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .strokeBorder(Color.green.opacity(0.3), lineWidth: 2)
                )
        )
    }
    
    @ViewBuilder
    private func movementCaptureIndicator(count: Int, secondsRemaining: Int) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "face.smiling.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Move Naturally")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("\(count) frames captured")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(Color.black.opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .strokeBorder(Color.green.opacity(0.3), lineWidth: 2)
                )
        )
    }
    
    @ViewBuilder
    private func successIndicator(text: String) -> some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.2)
            
            Text(text)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(Color.green.opacity(0.9))
        )
    }
    
    // MARK: - Progress Components
    
    @ViewBuilder
    private func progressBar(current: Int, total: Int) -> some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.green)
                        .frame(width: geometry.size.width * CGFloat(current) / CGFloat(total), height: 8)
                        .animation(.linear(duration: 0.1), value: current)
                }
            }
            .frame(height: 8)
            .padding(.horizontal, 40)
        }
    }
    
    @ViewBuilder
    private func movementTimer(seconds: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "timer")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            
            Text("\(seconds)s remaining")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Capsule().fill(Color.black.opacity(0.6)))
    }
    
    // MARK: - Helper Functions
    
    private func getDistanceGuidance(iodOk: Bool, iodNormOk: Bool) -> String {
        if !iodOk {
            switch faceManager.iodGuidance {
            case .moveCloser: return "Move Closer"
            case .moveFarther: return "Move Back"
            case .ok: return "Perfect Distance"
            case .noFace: return "Position Your Face"
            }
        }
        
        if !iodNormOk {
            return "Move Closer"
        }
        
        return "Adjust Distance"
    }
}

// MARK: - Directional Arrow Component

struct DirectionalArrow: View {
    let imageName: String
    let position: ArrowPosition
    let message: String
    
    @State private var animationOffset: CGFloat = 0
    @State private var opacity: Double = 0.9
    
    enum ArrowPosition {
        case top, bottom, left, right, center
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if position == .top {
                Spacer().frame(height: 140)
            }
            
            HStack(spacing: 0) {
                if position == .left {
                    Spacer().frame(width: 40)
                }
                
                VStack(spacing: 12) {
                    // Message above for bottom arrows, below for top arrows
                    if position == .bottom || position == .center {
                        Text(message)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Color.black.opacity(0.75)))
                    }
                    
                    // Arrow image
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: position == .center ? 100 : 70, height: position == .center ? 100 : 70)
                        .offset(y: animationOffsetValue)
                        .offset(x: animationOffsetValueHorizontal)
                        .opacity(opacity)
                        .onAppear {
                            startAnimation()
                        }
                    
                    // Message below for top arrows
                    if position == .top || position == .left || position == .right {
                        Text(message)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Color.black.opacity(0.75)))
                    }
                }
                
                if position == .right {
                    Spacer().frame(width: 40)
                }
            }
            
            if position == .bottom {
                Spacer().frame(height: 180)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }
    
    private var alignment: Alignment {
        switch position {
        case .top: return .top
        case .bottom: return .bottom
        case .left: return .leading
        case .right: return .trailing
        case .center: return .center
        }
    }
    
    private var animationOffsetValue: CGFloat {
        switch position {
        case .top: return -animationOffset
        case .bottom: return animationOffset
        case .center: return 0
        default: return 0
        }
    }
    
    private var animationOffsetValueHorizontal: CGFloat {
        switch position {
        case .left: return -animationOffset
        case .right: return animationOffset
        default: return 0
        }
    }
    
    private func startAnimation() {
        withAnimation(
            .easeInOut(duration: 0.8)
            .repeatForever(autoreverses: true)
        ) {
            animationOffset = 12
            opacity = 1.0
        }
    }
}
