import SwiftUI
import UIKit

struct ClaimChaiView: View {
    /// Prefer putting an asset named "chai" in Assets.xcassets.
    /// If you don’t have it yet, the fallback SF Symbol will show.
    var chaiAssetName: String = "chai"

    /// Hook your real API call here.
    var onClaim: () async throws -> Void = { }

    @State private var phase: Phase = .idle
    @State private var float = false
    @State private var glow = false
    @State private var shake: CGFloat = 0
    @State private var confettiTrigger = 0

    enum Phase: Equatable {
        case idle
        case claiming
        case claimed
        case failed(String)
    }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color.black, Color(.systemIndigo).opacity(0.5), Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Soft blobs
            Circle()
                .fill(Color(.systemTeal).opacity(0.18))
                .frame(width: 240, height: 240)
                .blur(radius: 10)
                .offset(x: -140, y: -220)

            Circle()
                .fill(Color(.systemPink).opacity(0.14))
                .frame(width: 280, height: 280)
                .blur(radius: 14)
                .offset(x: 160, y: 240)

            VStack(spacing: 18) {
                header

                chaiHero

                VStack(spacing: 10) {
                    claimButton
                    hintText
                }
                .padding(.top, 8)
            }
            .padding(24)
            .frame(maxWidth: 520)
            .background(glassCard)
            .padding(.horizontal, 18)

            ConfettiBurst(trigger: confettiTrigger)
                .allowsHitTesting(false)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { float.toggle() }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { glow.toggle() }
        }
    }

    // MARK: - UI blocks

    private var header: some View {
        VStack(spacing: 6) {
            Text("Your Chai is Ready ☕️")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Text("Claim it now — quick reward, instant vibe.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
        }
        .multilineTextAlignment(.center)
    }

    private var chaiHero: some View {
        ZStack {
            // Glow ring
            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [
                            Color(.systemYellow).opacity(glow ? 0.9 : 0.25),
                            Color(.systemOrange).opacity(glow ? 0.85 : 0.22),
                            Color(.systemTeal).opacity(glow ? 0.7 : 0.18),
                            Color(.systemYellow).opacity(glow ? 0.9 : 0.25)
                        ],
                        center: .center
                    ),
                    lineWidth: 4
                )
                .frame(width: 210, height: 210)
                .blur(radius: glow ? 0.6 : 1.2)
                .shadow(color: Color(.systemYellow).opacity(glow ? 0.35 : 0.12), radius: glow ? 18 : 10)

            // Inner card
            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 190, height: 190)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

            // Image
            chaiImage
                .frame(width: 150, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .shadow(color: .black.opacity(0.45), radius: 18, x: 0, y: 12)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
                .offset(y: float ? -8 : 8)
                .rotationEffect(.degrees(float ? -2.5 : 2.5))
                .offset(x: shake)
                .animation(.spring(response: 0.25, dampingFraction: 0.45), value: shake)
                .onTapGesture { chaiTapped() }
        }
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private var chaiImage: some View {
        Group {
            if UIImage(named: chaiAssetName) != nil {
                Image(chaiAssetName)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [Color(.systemOrange).opacity(0.9), Color(.systemYellow).opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 54, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.95))
                }
            }
        }
    }

    private var claimButton: some View {
        Button {
            Task { await claimTapped() }
        } label: {
            HStack(spacing: 10) {
                if phase == .claiming {
                    ProgressView()
                        .tint(.white)
                } else if phase == .claimed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.white)
                }

                Text(buttonTitle)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(PrimaryGlowButtonStyle(isEnabled: phase != .claiming && phase != .claimed))
        .disabled(phase == .claiming || phase == .claimed)
        .accessibilityLabel("Claim Chai")
    }

    private var hintText: some View {
        Group {
            switch phase {
            case .idle:
                Text("Tap the chai for a fun animation 😄")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            case .claiming:
                Text("Claiming…")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            case .claimed:
                Text("Claimed! Enjoy your chai ☕️✨")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
            case .failed(let msg):
                Text(msg)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(.systemRed).opacity(0.9))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: phase)
    }

    private var glassCard: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 24, x: 0, y: 18)
    }

    private var buttonTitle: String {
        switch phase {
        case .idle: return "Claim Chai"
        case .claiming: return "Processing"
        case .claimed: return "Claimed"
        case .failed: return "Try Again"
        }
    }

    // MARK: - Actions

    private func chaiTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        // Cute micro-shake
        withAnimation(.spring(response: 0.18, dampingFraction: 0.35)) { shake = 10 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.spring(response: 0.18, dampingFraction: 0.35)) { shake = -8 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.spring(response: 0.20, dampingFraction: 0.55)) { shake = 0 }
        }
    }

    private func claimTapped() async {
        guard phase != .claiming && phase != .claimed else { return }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        await MainActor.run { phase = .claiming }

        do {
            try await onClaim()
            await MainActor.run {
                phase = .claimed
                confettiTrigger += 1
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }catch {
            await MainActor.run {
                let msg =
                    (error as? LocalizedError)?.errorDescription ??
                    (error.localizedDescription.isEmpty ? "Something went wrong. Please try again." : error.localizedDescription)
                phase = .failed(msg)
            }
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }

    }
}

// MARK: - Button style

private struct PrimaryGlowButtonStyle: ButtonStyle {
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isEnabled
                                ? [Color(.systemOrange), Color(.systemPink)]
                                : [Color.white.opacity(0.18), Color.white.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color(.systemOrange).opacity(isEnabled ? 0.25 : 0.0), radius: 18, x: 0, y: 10)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

// MARK: - Confetti (pure SwiftUI)

private struct ConfettiBurst: View {
    let trigger: Int
    @State private var pieces: [Piece] = []

    struct Piece: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var size: CGFloat
        var rotation: Angle
        var drift: CGFloat
        var delay: Double
        var lifetime: Double
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { p in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(.white.opacity(0.9))
                        .frame(width: p.size, height: p.size * 2.2)
                        .rotationEffect(p.rotation)
                        .position(x: p.x, y: p.y)
                        .offset(x: p.drift, y: 0)
                        .opacity(0.9)
                }
            }
            .onChange(of: trigger) { _ in
                burst(in: geo.size)
            }
        }
        .ignoresSafeArea()
    }

    private func burst(in size: CGSize) {
        let centerX = size.width / 2
        let startY: CGFloat = size.height * 0.28

        var newPieces: [Piece] = (0..<70).map { i in
            Piece(
                x: centerX + CGFloat.random(in: -40...40),
                y: startY + CGFloat.random(in: -10...10),
                size: CGFloat.random(in: 5...9),
                rotation: .degrees(Double.random(in: 0...360)),
                drift: CGFloat.random(in: -140...140),
                delay: Double.random(in: 0...0.08),
                lifetime: Double.random(in: 0.9...1.3)
            )
        }

        pieces = newPieces

        for i in pieces.indices {
            let d = pieces[i].delay
            let life = pieces[i].lifetime
            DispatchQueue.main.asyncAfter(deadline: .now() + d) {
                withAnimation(.easeIn(duration: 0.06)) {
                    // just to ensure they appear
                }
                withAnimation(.easeInOut(duration: life)) {
                    pieces[i].y = size.height + 80
                    pieces[i].rotation += .degrees(Double.random(in: 180...540))
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeOut(duration: 0.2)) { pieces.removeAll() }
        }
    }
}


// MARK: - Flow wrapper (Claim button → FetchUserByID → ChaiUpdateView)

struct ClaimChaiFlowView: View {
    let userId: String
    let deviceKeyHash: String

    @EnvironmentObject var router: Router
    @StateObject private var userByIdViewModel = UserDataByIdViewModel()

    enum ClaimError: LocalizedError {
        case message(String)
        var errorDescription: String? {
            switch self {
            case .message(let s): return s
            }
        }
    }

    var body: some View {
        ClaimChaiView(onClaim: {
            await userByIdViewModel.fetch(userId: userId, deviceKeyHash: deviceKeyHash)

            if let err = userByIdViewModel.errorText {
                throw ClaimError.message(err)
            }

            // ✅ Check if chai < 5, then navigate to ChainUpdateView
            // If chai >= 5, show error
            if userByIdViewModel.chai > 5 {
                throw ClaimError.message("Chai limit reached. Come back later ☕️")
            }

            // ✅ Navigate to ChainUpdateView (ChaiUpdateView) if chai < 5
            await MainActor.run {
                router.navigate(to: .chaiUpdate(chai:userByIdViewModel.chai,userId: userId))
            }
        })
    }
}
