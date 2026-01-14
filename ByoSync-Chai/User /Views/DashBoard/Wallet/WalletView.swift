import SwiftUI

struct WalletView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("creditAvailable") private var creditAvailable: Double = 0.0
    @State private var selectedTabIndex: Int = 0
    @StateObject var transactionVM = TransactionViewModel()
    @EnvironmentObject var languageManager: LanguageManager
    @State private var isRotating = 0.0
    @State private var isCopied = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.systemBackground),
                        Color.indigo.opacity(0.03)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // MARK: - Balance Card
                    VStack(spacing: 24) {
                        VStack(spacing: 8) {
                            Text(L("wallet.current_balance"))
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.white.opacity(0.8))
                                .textCase(.uppercase)
                                .tracking(1.2)
                            HStack {
                                Image("byosync_coin")
                                    .resizable()
                                    .interpolation(.high)
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                                    .rotation3DEffect(
                                        .degrees(isRotating),
                                        axis: (x: 0.0, y: 1.0, z: 0.0)
                                    )
                                    .onAppear {
                                        withAnimation(.linear(duration: 1.0)) {
                                            isRotating = 360.0
                                        }
                                    }
                                
                                Text("\(String(format: "%.2f", UserSession.shared.wallet))")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        
                        // Balance breakdown
                        HStack(spacing: 16) {
                            balanceBreakdownItem(
                                label: "Refer & Earn",
                                value: "\(String(format: "%.2f", 500 - creditAvailable)) Coinds",
                                icon: "gift.fill",
                                color: .green
                            )
                            
                            balanceBreakdownItem(
                                label: "This month",
                                value: "\(transactionVM.transactions.count)",
                                icon: "list.bullet",
                                color: .orange
                            )
                        }
                        .padding(.top, 8)
                    }
                    .padding(.vertical, 32)
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity)
                    .background(
                        ZStack {
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.indigo.opacity(0.9),
                                    Color.indigo
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            Circle()
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 200, height: 200)
                                .offset(x: -80, y: -60)
                                .blur(radius: 40)
                            Circle()
                                .fill(Color.indigo.opacity(0.3))
                                .frame(width: 150, height: 150)
                                .offset(x: 100, y: 80)
                                .blur(radius: 50)
                        }
                    )
                    .cornerRadius(28)
                    .shadow(color: Color.indigo.opacity(0.4), radius: 20, x: 0, y: 10)
                    .padding(.horizontal, 24)
                    
                    // MARK: - Referral Code Card
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.indigo)
                            Text("Your Referral Code")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("CODE")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                    .tracking(0.8)
                                
                                Text(UserSession.shared.currentUser?.refferalCode ?? "N/A")
                                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                                    .foregroundColor(.primary)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                copyReferralCode()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc.fill")
                                        .font(.system(size: 16))
                                    Text(isCopied ? "Copied!" : "Copy")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: isCopied ? [Color.green, Color.green.opacity(0.8)] : [Color.indigo, Color.indigo.opacity(0.8)]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(20)
                    .background(Color(.systemBackground))
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                    .padding(.horizontal, 24)
                                        
                    Spacer()
                }
                .padding(.top, 20)
            }
            .navigationTitle(L("wallet.title"))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear{
                transactionVM.fetchMonthlyTransactions(month: 11, year: 2025, reportType: .view)
            }
        }
    }
    
    // MARK: - Helper Functions
    private func copyReferralCode() {
        if let referralCode = UserSession.shared.currentUser?.refferalCode {
            UIPasteboard.general.string = referralCode
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isCopied = true
            }
            
            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            // Reset after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    isCopied = false
                }
            }
        }
    }
    
    private func balanceBreakdownItem(
        label: String,
        value: String,
        icon: String,
        color: Color
    ) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
            if label.isEmpty {
                ProgressView()
            }else{
                Text(value)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }

}

#Preview {
    WalletView()
        .environmentObject(LanguageManager.shared)
}
