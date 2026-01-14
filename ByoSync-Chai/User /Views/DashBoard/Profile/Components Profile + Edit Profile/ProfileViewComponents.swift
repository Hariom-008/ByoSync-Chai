import Foundation
import SwiftUI

// MARK: - Edit Field Row Component
struct EditFieldRow: View {
    let icon: String
    let label: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(Color(hex: "4B548D"))
                    .frame(width: 24)
                
                TextField("", text: $text)
                    .font(.subheadline)
                    .keyboardType(keyboardType)
                    .autocapitalization(keyboardType == .emailAddress ? .none : .words)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(Color(hex: "F5F7FA"))
            .cornerRadius(12)
        }
    }
}

struct MenuOptionRow: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.body)
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        }
    }
}


// MARK: - Profile Info Row Component
struct ProfileInfoRow: View {
    let icon: String
    let label: String
    let value: String
    var iconColor: Color = Color(hex: "4B548D")
    @State private var openEmailOTPView: Bool = false
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(Color(hex: "4B548D"))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            // ✅ Show verify button only if email is not verified and this is the email row
            if !UserSession.shared.isEmailVerified && label == "Email Address" {
                Button {
                    openEmailOTPView.toggle()
                } label: {
                    Text("Verify Email")
                        .foregroundStyle(.black)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.black, lineWidth: 1)
                        )
                }
            }
        }
        .sheet(isPresented: $openEmailOTPView) {
            EmailVerificationView()
        }
    }
}


// MARK: - Rewards + Invite row
 struct RewardsInviteRow: View {
    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 12){
                Image("celebrationPeople")
                    .resizable()
                    .frame(width: 120, height: 120)
                VStack{
                    Text("₹1066")
                        .font(.headline).bold()
                        .foregroundColor(.black)
                    Text("Rewards Earned!")
                        .font(.caption)
                        .foregroundColor(.black.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.black.opacity(0.05))
            )
            .frame(height: 120)
            
            // Invite friends
            VStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color(hex: "4B548D"))
                Text("Invite\nfriends")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.black)
            }
            .frame(width: 110, height: 120)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.black.opacity(0.05))
            )
        }
    }
}


struct SlideToLogoutButton: View {
    let isDisabled: Bool
    let action: () -> Void
    
    @State private var offsetX: CGFloat = 0
    @State private var isCompleted = false
    @State private var hasTriggeredHaptic = false
    
    // Reusable haptic generators (created once)
    private let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    
    private let buttonHeight: CGFloat = 60
    private let thumbSize: CGFloat = 52
    
    var body: some View {
        GeometryReader { geometry in
            let maxOffset = geometry.size.width - thumbSize - 8
            let progress = offsetX / maxOffset
            
            ZStack(alignment: .leading) {
                // Background with optimized gradient
                RoundedRectangle(cornerRadius: 30)
                    .fill(backgroundGradient(progress: progress))
                    .shadow(
                        color: isDisabled ? .clear : Color.red.opacity(0.3),
                        radius: 15,
                        y: 8
                    )
                    .drawingGroup() // Optimizes shadow rendering
                
                // Progress fill
                if !isDisabled {
                    RoundedRectangle(cornerRadius: 30)
                        .fill(
                            LinearGradient(
                                colors: [Color.red, Color.red.opacity(0.9)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: offsetX + thumbSize)
                }
                
                // Text label
                HStack {
                    Spacer()
                    Text("Slide to Logout")
                       // .font(.system(size: 16, weight: .semibold, design: .rounded))
//                        .foregroundColor(isDisabled ? .gray : .black.opacity(0.9))
//                        .opacity(1 - progress * 1.5)
                    Spacer()
                }
                
                // Sliding thumb
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 26)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 2, y: 2)
                        
                        Image(systemName: "rectangle.portrait.and.arrow.right.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(thumbColor(progress: progress))
                    }
                    .frame(width: thumbSize, height: thumbSize)
                    .offset(x: offsetX)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard !isDisabled && !isCompleted else { return }
                                
                                // Direct update without animation for smooth dragging
                                let newOffset = max(0, min(value.translation.width, maxOffset))
                                offsetX = newOffset
                                
                                // Haptic feedback when reaching the end (only once)
                                if newOffset >= maxOffset * 0.95 && !hasTriggeredHaptic {
                                    impactGenerator.impactOccurred()
                                    hasTriggeredHaptic = true
                                }
                                
                                // Reset haptic flag when dragging back
                                if newOffset < maxOffset * 0.9 {
                                    hasTriggeredHaptic = false
                                }
                            }
                            .onEnded { _ in
                                guard !isDisabled && !isCompleted else { return }
                                
                                if offsetX >= maxOffset * 0.85 {
                                    // Complete the action
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        offsetX = maxOffset
                                    }
                                    isCompleted = true
                                    
                                    // Success haptic
                                    notificationGenerator.notificationOccurred(.success)
                                    
                                    // Trigger action after animation
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        action()
                                    }
                                } else {
                                    // Reset with spring animation
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                        offsetX = 0
                                    }
                                }
                                
                                // Reset haptic flag
                                hasTriggeredHaptic = false
                            }
                    )
                    
                    Spacer()
                }
                .padding(4)
            }
            .frame(height: buttonHeight)
        }
        .frame(height: buttonHeight)
        .onAppear {
            // Prepare haptic generators
            impactGenerator.prepare()
            notificationGenerator.prepare()
        }
    }
    
    // MARK: - Helper Functions
    
    private func backgroundGradient(progress: CGFloat) -> LinearGradient {
        if isDisabled {
            return LinearGradient(
                colors: [Color.gray.opacity(0.3 + progress * 0.7)],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            return LinearGradient(
                colors: [
                    Color.red.opacity(0.3 + progress * 0.7),
                    Color.red.opacity(0.2 + progress * 0.8)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
    
    private func thumbColor(progress: CGFloat) -> Color {
        if isDisabled {
            return .gray
        } else {
            return progress > 0.8 ? .green : .red
        }
    }
}
