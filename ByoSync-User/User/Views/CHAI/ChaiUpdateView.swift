import SwiftUI

struct ChaiUpdateView: View {
    @StateObject private var vm = ChaiViewModel()
    @EnvironmentObject var router: Router
    @EnvironmentObject var userSession: UserSession
    @Environment(\.dismiss) var dismiss
    let chai: Int
    let userId: String
    
    var body: some View {
        ZStack {
            // Clean background
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    // Header with icon
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.orange.opacity(0.2), .orange.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "cup.and.saucer.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.orange, .orange.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .padding(.top, 20)
                        
                        VStack(spacing: 6) {
                            Text("Congrats You Claimed a Cup!")
                                .font(.system(size: 28, weight: .bold))
                            
                            Text("Building your streak")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 20)
                    
                    // Main chai meter card
                    VStack(spacing: 24) {
                        ChaiMeter(chai: chai, isLoading: vm.isLoading)
                        
                        // Status indicator
                        if chai >= 5 {
                            HStack(spacing: 8) {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.yellow, .orange],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                Text("Chain Complete!")
                                    .fontWeight(.semibold)
                            }
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.yellow.opacity(0.1))
                            .cornerRadius(20)
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "flame.fill")
                                    .foregroundColor(.orange)
                                Text("\(5 - chai) more to complete chain")
                                    .fontWeight(.medium)
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        }
                    }
                    .padding(28)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(24)
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
                    .padding(.horizontal, 20)
                    
                    // Status messages
                    VStack(spacing: 12) {
                        if let msg = vm.lastMessage {
                            StatusBadge(
                                icon: "checkmark.circle.fill",
                                message: msg,
                                color: .green
                            )
                            .transition(.scale.combined(with: .opacity))
                        }
                        
                        if let err = vm.lastError {
                            StatusBadge(
                                icon: "exclamationmark.triangle.fill",
                                message: err,
                                color: .red
                            )
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 20)
                    .animation(.spring(response: 0.5, dampingFraction: 0.75), value: vm.lastMessage)
                    .animation(.spring(response: 0.5, dampingFraction: 0.75), value: vm.lastError)
                    
                    // Reset section with warning note
                    VStack(spacing: 16) {
                        // Warning note
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.orange)
                            
                            Text("By pressing this button you'll be redirected to enter phone number and all your data gets cleared")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(14)
                        .background(Color.orange.opacity(0.08))
                        .cornerRadius(12)
                        
                        // Reset button
                        Button(action: {
                            print("🔄 ChaiUpdate: Reset button pressed - clearing data and navigating to root")
                            handleReset()
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 16, weight: .semibold))
                                
                                Text("Claim Again")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [.red, .red.opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(14)
                            .shadow(color: .red.opacity(0.3), radius: 8, y: 4)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    Spacer(minLength: 40)
                }
            }
        }
        .task(id: userId) {
            let trimmed = userId.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                print("❌ ChaiUpdate: userId is empty")
                return
            }
            print("☕️ ChaiUpdate: Updating chai for user \(trimmed)")
            await vm.updateChai(userId: trimmed)
            if vm.successfullyUpdateChai {
                print("✅ ChaiUpdate: Successfully updated chai count")
                // dismiss()
            }
        }
    }
    
    // MARK: - Reset Handler
    private func handleReset() {
        print("🧹 ChaiUpdate: Starting data cleanup...")
        
        // Clear user session data
        print("🧹 ChaiUpdate: Clearing user session")
        userSession.clearUser()
        
        // Clear any stored user defaults if needed
        print("🧹 ChaiUpdate: Clearing UserDefaults")
        UserDefaults.standard.removeObject(forKey: "userId")
        UserDefaults.standard.removeObject(forKey: "deviceKeyHash")
        UserDefaults.standard.removeObject(forKey: "userPhone")
        // Add any other UserDefaults keys you want to clear
        
        // Reset navigation stack and go to root
        print("🧭 ChaiUpdate: Resetting router to root view")
        router.reset()
        
        print("✅ ChaiUpdate: Data cleared and navigated to root")
    }
}

// MARK: - Status Badge
private struct StatusBadge: View {
    let icon: String
    let message: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
            
            Text(message)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(16)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Animated Meter
private struct ChaiMeter: View {
    let chai: Int          // 0...5
    let isLoading: Bool
    
    @State private var pulse = false
    @State private var spin = false
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                // Ring background
                Circle()
                    .stroke(
                        Color.orange.opacity(0.15),
                        lineWidth: 12
                    )
                
                // Ring progress with gradient
                Circle()
                    .trim(from: 0, to: CGFloat(chai) / 5.0)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                .orange.opacity(0.7),
                                .orange,
                                .yellow.opacity(0.8)
                            ]),
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5, dampingFraction: 0.75), value: chai)
                    .shadow(color: .orange.opacity(0.3), radius: 4, y: 2)
                
                // Center content
                VStack(spacing: 8) {
                    Image(systemName: isLoading ? "cup.and.saucer.fill" : "cup.and.saucer.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .yellow],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .rotationEffect(isLoading ? .degrees(spin ? 360 : 0) : .degrees(0))
                        .animation(
                            isLoading ? .linear(duration: 1.2).repeatForever(autoreverses: false) : .default,
                            value: spin
                        )
                    
                    Text("\(chai)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .orange.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("of 5 chais")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                .scaleEffect(pulse ? 1.08 : 1.0)
                .animation(.spring(response: 0.5, dampingFraction: 0.75), value: pulse)
            }
            .frame(width: 140, height: 140)
            
            // 5-cup indicator row with better styling
            HStack(spacing: 14) {
                ForEach(0..<5, id: \.self) { i in
                    VStack(spacing: 4) {
                        Image(systemName: i < chai ? "cup.and.saucer.fill" : "cup.and.saucer")
                            .font(.system(size: 20))
                            .foregroundStyle(
                                i < chai ?
                                LinearGradient(
                                    colors: [.orange, .yellow],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [.secondary.opacity(0.3), .secondary.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .scaleEffect(i == chai - 1 && pulse ? 1.2 : 1.0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.75), value: chai)
                        
                        // Progress dots
                        Circle()
                            .fill(i < chai ? Color.orange : Color.secondary.opacity(0.2))
                            .frame(width: 6, height: 6)
                            .scaleEffect(i == chai - 1 && pulse ? 1.3 : 1.0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.75), value: chai)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Color(UIColor.tertiarySystemGroupedBackground))
            .cornerRadius(16)
        }
        .onAppear {
            print("☕️ ChaiMeter: Appeared with chai count \(chai)")
            spin = true
        }
        .onChange(of: chai) { oldValue, newValue in
            print("☕️ ChaiMeter: Chai updated from \(oldValue) to \(newValue)")
            pulse = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                pulse = false
            }
        }
    }
}
