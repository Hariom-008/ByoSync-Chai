import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @StateObject var socketManager = SocketIOManager.shared  // Add this
    @State private var selected: MainTab = .home
    @State private var openPayView = false
    @State var hideTabBar: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // MARK: - Active content
                Group {
                    switch selected {
                    case .home:
                        HomeView(hideTabBar: $hideTabBar)
                    case .profile:
                        ProfileView()
                    }
                }
                .ignoresSafeArea(.all, edges: .bottom)
                
                // MARK: - Custom Tab Bar
                if !hideTabBar {
                    VStack {
                        Spacer(minLength: 0)
                        
                        ZStack {
                            // Glassmorphic background
                            RoundedRectangle(cornerRadius: 24)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24)
                                        .stroke(.white.opacity(0.2), lineWidth: 0.5)
                                )
                                .frame(height: 72)
                                .shadow(color: .black.opacity(0.12), radius: 12, y: -4)
                                .padding(.horizontal, 20)
                            
                            HStack(spacing: 0) {
                                // Home Tab
                                TabItem(
                                    systemName: "house.fill",
                                    title: L("tab_home"),
                                    isSelected: selected == .home
                                ) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selected = .home
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                
                                Spacer().frame(width: 80)
                                
                                // Profile Tab
                                TabItem(
                                    systemName: "person.fill",
                                    title: "Profile",
                                    isSelected: selected == .profile
                                ) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selected = .profile
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .padding(.horizontal, 32)
                            
                            // Center Pay button
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    openPayView.toggle()
                                    hideTabBar.toggle()
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(
                                            RadialGradient(
                                                colors: [
                                                    Color(hex: "4B548D").opacity(0.3),
                                                    Color.clear
                                                ],
                                                center: .center,
                                                startRadius: 34,
                                                endRadius: 44
                                            )
                                        )
                                        .frame(width: 88, height: 88)
                                    
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color(hex: "5B62A0"),
                                                    Color(hex: "4B548D")
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 68, height: 68)
                                        .shadow(color: Color(hex: "4B548D").opacity(0.4), radius: 12, y: 4)
                                        .overlay(
                                            Circle()
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [.white.opacity(0.3), .clear],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 1
                                                )
                                        )
                                    
                                    Text("Pay")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                                .scaleEffect(openPayView ? 0.95 : 1.0)
                            }
                            .offset(y: -28)
                            .buttonStyle(.plain)
                        }
                        .padding(.bottom, 8)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationBarBackButtonHidden(true)
            .environment(\.locale, .init(identifier: languageManager.currentLanguageCode))
            .navigationDestination(isPresented: $openPayView) {
                EnterAmountView(hideTabBar: $hideTabBar)
            }
        }
    }
}

