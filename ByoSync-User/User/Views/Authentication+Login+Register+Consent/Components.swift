import SwiftUI

// MARK: - Animated Background Blobs

struct AnimatedBackgroundBlobs: View {
    let visible: Bool
    let logoBlue: Color
    let logoPurple: Color
    
    @State private var offset1: CGFloat = 0
    @State private var offset2: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Blob 1 - Blue
            Circle()
                .fill(logoBlue)
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .opacity(visible ? 0.15 : 0)
                .offset(x: -100 + offset1, y: 100)
            
            // Blob 2 - Purple
            Circle()
                .fill(logoPurple)
                .frame(width: 250, height: 250)
                .blur(radius: 60)
                .opacity(visible ? 0.18 : 0)
                .offset(x: UIScreen.main.bounds.width - 150 + offset2, y: -50)
            
            // Blob 3 - Mid gradient color
            Circle()
                .fill(
                    LinearGradient(
                        colors: [logoBlue, logoPurple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 200, height: 200)
                .blur(radius: 50)
                .opacity(visible ? 0.12 : 0)
                .offset(x: 50, y: UIScreen.main.bounds.height - 200 + offset1)
        }
        .animation(.easeInOut(duration: 1.0), value: visible)
        .onAppear {
            withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                offset1 = 50
            }
            
            withAnimation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true)) {
                offset2 = -40
            }
        }
    }
}

// MARK: - Feature Pill

struct FeaturePill: View {
    let icon: String
    let title: String
    let subtitle: String
    let logoBlue: Color
    let logoPurple: Color
    
    var body: some View {
        HStack(spacing: 14) {
            // Icon circle with gradient
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [logoBlue.opacity(0.15), logoPurple.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [logoBlue, logoPurple],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(red: 0.118, green: 0.161, blue: 0.231))
                
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(Color(red: 0.392, green: 0.455, blue: 0.545))
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .frame(minWidth: 200)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        )
    }
}

// MARK: - Glass Button

struct GlassButton: View {
    let text: String
    let icon: String
    let isPrimary: Bool
    let logoBlue: Color
    let logoPurple: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            print("🔘 Button tapped: \(text)")
            action()
        }) {
            HStack(spacing: 10) {
                if !icon.isEmpty{
                    Image(systemName: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                }
                Text(text)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(logoBlue == .gray ? Color.gray.opacity(0.6) : Color.white)
            }
            .foregroundColor(isPrimary ? .white : logoBlue)
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        isPrimary ?
                        LinearGradient(
                            colors: [logoBlue, logoPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [Color.white, Color.white],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .black.opacity(isPrimary ? 0.15 : 0.08), radius: isPrimary ? 8 : 4, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isPrimary ? Color.clear : Color.white.opacity(0.5), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isPressed = false
                    }
                }
        )
    }
}

// MARK: - Camera Permission UI

struct CameraPermissionUI: View {
    let logoBlue: Color
    let logoPurple: Color
    let onDismiss: () -> Void
    let onOpenSettings: () -> Void
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.972, green: 0.980, blue: 0.988),
                    Color(red: 0.937, green: 0.965, blue: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Icon with gradient
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [logoBlue.opacity(0.15), logoPurple.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "lock.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [logoBlue, logoPurple],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                
                VStack(spacing: 8) {
                    Text("Camera Access Required")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(red: 0.118, green: 0.161, blue: 0.231))
                    
                    Text("We need camera permission for secure biometric login")
                        .font(.system(size: 16))
                        .foregroundColor(Color(red: 0.392, green: 0.455, blue: 0.545))
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 12) {
                    GlassButton(
                        text: "Open Settings",
                        icon: "gearshape.fill",
                        isPrimary: true,
                        logoBlue: logoBlue,
                        logoPurple: logoPurple,
                        action: onOpenSettings
                    )
                    
                    Button(action: {
                        print("↩️ Go Back tapped")
                        onDismiss()
                    }) {
                        Text("Go Back")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [logoBlue, logoPurple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.1), radius: 12, y: 6)
            )
            .padding(24)
        }
    }
}
