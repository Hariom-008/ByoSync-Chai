import SwiftUI

struct EnterAmountView: View {
    @State private var amount: String = ""
    @FocusState private var isAmountFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @Binding var hideTabBar: Bool
    
    // Animation states
    @State private var showContent: Bool = false
    @State private var showQuickAmounts: Bool = false
    @State private var pulseAnimation: Bool = false
    
    // Simple amount validation
    private var isValidAmount: Bool {
        if let value = Int(amount), value > 0 {
            return true
        }
        return false
    }
    
    // Formatted amount for display
    private var formattedAmount: String {
        if amount.isEmpty { return "0" }
        if let value = Int(amount) {
            return value.formatted(.number.grouping(.automatic))
        }
        return amount
    }
    

    var body: some View {
        NavigationStack {
            ZStack {
                // MARK: - Background
                backgroundGradient
                
                VStack(spacing: 0) {
                    // MARK: - Header
                    header
                    
                    // MARK: - Main Content
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 40) {
                            // Top spacing
                            Spacer()
                                .frame(height: 20)
                            
                            // Title Section
                            titleSection
                            
                            // Amount Input Card
                            amountInputCard
                            
                            // Quick Amount Buttons
                            quickAmountSection
                            
                            // Bottom spacing
                            Spacer()
                                .frame(height: 20)
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    // MARK: - Bottom Action
                    bottomActionSection
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                setupView()
            }
            .onDisappear {
                hideTabBar = false
            }
        }
    }
    
    // MARK: - Background Gradient
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color(hex: "F8F9FD"), location: 0.0),
                .init(color: Color(hex: "EEF0F8"), location: 0.5),
                .init(color: Color(hex: "E8EAF6"), location: 1.0)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Header
    private var header: some View {
        HStack {
            Button {
                generateHaptic(.light)
                dismiss()
                hideTabBar = false
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 44, height: 44)
                        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
                    
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(hex: "4B548D"))
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : -20)
    }
    
    // MARK: - Title Section
    private var titleSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("Enter Amount")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("How many coin would you like to pay?")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
    }
    
    // MARK: - Amount Input Card
    private var amountInputCard: some View {
        VStack(spacing: 20) {
            // Amount Input
            HStack(alignment: .center, spacing: 12) {
                // Token Icon
                Image("byosync_coin")
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    .shadow(color: Color(hex: "4B548D").opacity(0.2), radius: 8, x: 0, y: 4)
                
                // Amount TextField
                VStack(alignment: .leading, spacing: 4) {
                    TextField("0", text: $amount)
                        .keyboardType(.numberPad)
                        .focused($isAmountFocused)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "4B548D"), Color(hex: "6B74A8")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .onChange(of: amount) { newValue in
                            // Filter to numbers only
                            let filtered = newValue.filter(\.isNumber)
                            
                            // Limit to reasonable amount (e.g., 1 million tokens)
                            if let intValue = Int(filtered), intValue > 1_000_000 {
                                amount = "1000000"
                            } else {
                                amount = filtered
                            }
                        }
                }
                
                Spacer()
                
                // Clear button
                if !amount.isEmpty {
                    Button {
                        generateHaptic(.light)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            amount = ""
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        isAmountFocused ?
                        LinearGradient(
                            colors: [
                                Color(hex: "4B548D").opacity(0.4),
                                Color(hex: "6B74A8").opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                            LinearGradient(
                                colors: [Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                        lineWidth: 2
                    )
            )
        }
        .scaleEffect(showContent ? 1 : 0.9)
        .opacity(showContent ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: amount.isEmpty)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isAmountFocused)
    }
    
    // MARK: - Quick Amount Section
    private var quickAmountSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Quick Select")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach([50, 100, 200, 500, 1000, 2000], id: \.self) { value in
                    quickAmountButton(value: value)
                }
            }
        }
        .opacity(showQuickAmounts ? 1 : 0)
        .offset(y: showQuickAmounts ? 0 : 20)
    }
    
    private func quickAmountButton(value: Int) -> some View {
        Button {
            generateHaptic(.medium)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                amount = "\(value)"
            }
        } label: {
            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image("byosync_coin")
                        .resizable()
                        .frame(width: 16, height: 16)
                        .clipShape(Circle())
                    
                    Text("\(value)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .foregroundColor(amount == "\(value)" ? .white : Color(hex: "4B548D"))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        amount == "\(value)" ?
                        LinearGradient(
                            colors: [Color(hex: "4B548D"), Color(hex: "6B74A8")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                            LinearGradient(
                                colors: [Color.white],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                    )
                    .shadow(
                        color: amount == "\(value)" ?
                        Color(hex: "4B548D").opacity(0.3) :
                            Color.black.opacity(0.04),
                        radius: amount == "\(value)" ? 12 : 8,
                        x: 0,
                        y: amount == "\(value)" ? 6 : 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        amount == "\(value)" ? Color.clear : Color(hex: "4B548D").opacity(0.1),
                        lineWidth: 1
                    )
            )
            .scaleEffect(amount == "\(value)" ? 1.02 : 1.0)
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    // MARK: - Bottom Action Section
    private var bottomActionSection: some View {
        VStack(spacing: 12) {
            NavigationLink(
                destination: SortedUsersView(hideTabBar: $hideTabBar, amount: $amount)
            ) {
                HStack(spacing: 10) {
                    Text("Continue")
                        .font(.system(size: 17, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .foregroundColor(.white)
                .background(
                    Group {
                        if isValidAmount {
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(hex: "4B548D"),
                                    Color(hex: "6B74A8")
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        } else {
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.gray.opacity(0.2)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        }
                    }
                )
                .cornerRadius(16, corners: .allCorners)
                .shadow(
                    color: isValidAmount ? Color(hex: "4B548D").opacity(0.4) : .clear,
                    radius: isValidAmount ? 16 : 0,
                    x: 0,
                    y: isValidAmount ? 8 : 0
                )
            }
            .disabled(!isValidAmount)
            .simultaneousGesture(
                TapGesture().onEnded {
                    if isValidAmount {
                        generateHaptic(.heavy)
                    }
                }
            )
            .scaleEffect(isValidAmount ? 1 : 0.98)
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: isValidAmount)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
        .background(
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color.clear, location: 0.0),
                    .init(color: Color(hex: "F8F9FD"), location: 0.3),
                    .init(color: Color(hex: "F8F9FD"), location: 1.0)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
            .offset(y: -20)
        )
    }
    
    // MARK: - Helper Functions
    private func setupView() {
        hideTabBar = true
        
        // Staggered animations
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
            showContent = true
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) {
            showQuickAmounts = true
        }
        
        // Pulse animation
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            pulseAnimation = true
        }
        
        // Focus on input after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isAmountFocused = true
        }
    }
    
    private func generateHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}
#Preview {
    EnterAmountView(hideTabBar: .constant(false))
}
