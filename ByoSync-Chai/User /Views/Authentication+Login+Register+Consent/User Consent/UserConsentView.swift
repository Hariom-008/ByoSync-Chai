import SwiftUI

struct UserConsentView: View {
    var onComplete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    // Keep your existing naming convention
    @State private var isConsentGiven = false
    @State private var showAlert = false
    
    // Expandable sections state
    @State private var secDataSecurity = true
    @State private var secProcessing = false
    @State private var secRetention = false
    @State private var secDeletion = false
    @State private var secModel = false
    @State private var secTerms = false
    @State private var secCollect = false
    @State private var secProtect = false
    @State private var secRights = false
    
    private let TAG = "UserConsentView"
    
    var body: some View {
        ZStack {
            Color(hex: "F7F8FA")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Content
                ScrollView {
                    VStack(spacing: 12) {
                        headerCard
                        summaryCard
                        
                        // Expandable sections
                        expandableSection(
                            icon: "lock.fill",
                            title: "Data Security & Privacy",
                            isExpanded: $secDataSecurity
                        ) {
                            bulletPoint("We protect data in transit and at rest using strong encryption.")
                            bulletPoint("Sensitive identifiers are protected with device-level cryptography where possible.")
                        }
                        
                        expandableSection(
                            icon: "hand.raised.fill",
                            title: "Data Processing",
                            isExpanded: $secProcessing
                        ) {
                            bulletPoint("Certain sensitive identifiers are protected using device-level cryptography.")
                            bulletPoint("Other data may be processed securely on our servers to provide and improve our services.")
                        }
                        
                        expandableSection(
                            icon: "doc.text.fill",
                            title: "Data Retention & Deletion",
                            isExpanded: $secRetention
                        ) {
                            bulletPoint("Verification images are retained for a limited period (typically up to 30 days) unless required for security, audit, or model improvement purposes.")
                            bulletPoint("Training datasets are anonymized and retained only as long as necessary.")
                        }
                        
                        expandableSection(
                            icon: "trash.fill",
                            title: "Account Deletion",
                            isExpanded: $secDeletion
                        ) {
                            bulletPoint("You can request account deletion by contacting support at: info@byosync.in", hasEmail: true)
                            bulletPoint("After deletion, we remove or anonymize associated data unless retention is required for legal/security reasons.")
                            bulletPoint("Some device/security logs may remain for a limited period to prevent repeated abuse.")
                        }
                        
                        expandableSection(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "Model Improvement",
                            isExpanded: $secModel
                        ) {
                            bulletPoint("We may use a limited subset of data to improve accuracy, liveness detection, and fraud resistance.")
                            bulletPoint("We apply strict access control and track access via audit logs.")
                        }
                        
                        expandableSection(
                            icon: "doc.plaintext.fill",
                            title: "User Consent & Terms",
                            isExpanded: $secTerms
                        ) {
                            bulletPoint("By using ByoSync, you confirm you are 18+ and legally allowed to use the app.")
                            bulletPoint("You agree that we may process data as described to provide verification and security features.")
                            bulletPoint("If the policy changes materially, we may ask you to review and re-consent.")
                        }
                        
                        expandableSection(
                            icon: "list.bullet.clipboard.fill",
                            title: "What We Collect",
                            isExpanded: $secCollect
                        ) {
                            bulletPoint("Face scan data used for verification (and related derived signals for security checks).")
                            bulletPoint("Device and app identifiers needed for login security, anti-fraud, and service operation.")
                            bulletPoint("Basic usage and diagnostic logs to improve reliability and detect abuse.")
                        }
                        
                        expandableSection(
                            icon: "shield.fill",
                            title: "How We Protect Your Data",
                            isExpanded: $secProtect
                        ) {
                            bulletPoint("Encryption in transit and at rest, plus secure key management practices.")
                            bulletPoint("Least-privilege access controls, audit logging, and monitoring for suspicious activity.")
                            bulletPoint("Trusted service providers are used under contractual obligations and security safeguards.")
                        }
                        
                        expandableSection(
                            icon: "person.badge.shield.checkmark.fill",
                            title: "Your Rights",
                            isExpanded: $secRights
                        ) {
                            bulletPoint("Access, correction, and deletion requests are supported through Settings or support.")
                            bulletPoint("You can withdraw consent anytime; withdrawing consent may disable the account.")
                            bulletPoint("You can contact info@byosync.in for privacy requests and grievance support.", hasEmail: true)
                        }
                        
                        Spacer().frame(height: 6)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                
                // Bottom bar
                bottomBar
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            print("🟢 [\(TAG)] UserConsentScreen opened")
        }
        .onDisappear {
            print("🔴 [\(TAG)] UserConsentScreen closed")
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack(spacing: 0) {
            Button(action: {
                print("🔙 [\(TAG)] Back button clicked → dismiss()")
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }
            
            Text("Privacy & Terms")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
            
            Spacer().frame(width: 44) // Balance the back button
        }
        .frame(height: 60)
        .background(Color(hex: "111827"))
    }
    
    // MARK: - Header Card
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ByoSync Privacy Policy & Terms")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Color(hex: "111827"))
            
            Text("Your trusted app for secure face-based authentication")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "6B7280"))
            
            Spacer().frame(height: 2)
            
            HStack {
                Text("Last Updated: December 2025")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "374151"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 999)
                            .fill(Color(hex: "F3F4F6"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 999)
                                    .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
                            )
                    )
                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "E6E8EE"), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Summary Card
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundColor(Color(hex: "1F4FD6"))
                
                Text("Quick Summary")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: "111827"))
            }
            
            Divider()
                .background(Color(hex: "E5E7EB"))
            
            bulletPoint("We use your face scan only to verify identity and prevent fraud.")
            bulletPoint("We store only what's needed to run the service and improve reliability.")
            bulletPoint("You stay in control: access, correction, deletion, and consent withdrawal are supported.")
            bulletPoint("We use trusted service providers under security and contractual safeguards.")
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "F8FAFF"))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "DCE6FF"), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Expandable Section
    private func expandableSection<Content: View>(
        icon: String,
        title: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.wrappedValue.toggle()
                }
            }) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(Color(hex: "111827"))
                        .frame(width: 20)
                    
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(hex: "111827"))
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "6B7280"))
                        .rotationEffect(.degrees(isExpanded.wrappedValue ? 180 : 0))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            
            if isExpanded.wrappedValue {
                VStack(alignment: .leading, spacing: 8) {
                    content()
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "E6E8EE"), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Bullet Point
    private func bulletPoint(_ text: String, hasEmail: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Color(hex: "1F4FD6"))
                .frame(width: 6, height: 6)
                .padding(.top, 7)
            
            if hasEmail {
                Text(attributedString(from: text))
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "374151"))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(text)
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "374151"))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    // MARK: - Bottom Bar
    private var bottomBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button(action: {
                    isConsentGiven.toggle()
                }) {
                    HStack {
                        Image(systemName: isConsentGiven ? "checkmark.square.fill" : "square")
                            .font(.system(size: 22))
                            .foregroundColor(isConsentGiven ? Color(hex: "1F4FD6") : Color(hex: "9CA3AF"))
                        
                        Text("I have read and understood the ByoSync Privacy Policy and Terms, and I agree to the collection, use, and processing of my data as described above.")
                            .font(.system(size: 12.5))
                            .foregroundColor(Color(hex: "111827"))
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 2)
            
            HStack(spacing: 12) {
                Button(action: {
                    print("❌ [\(TAG)] Decline clicked → dismiss()")
                    dismiss()
                }) {
                    Text("Decline")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "111827"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(hex: "111827"), lineWidth: 1)
                        )
                }
                
                Button(action: {
                    if isConsentGiven {
                        print("✅ [\(TAG)] Accept clicked → navigating to register")
                        onComplete()
                    }
                }) {
                    Text("Accept")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isConsentGiven ? Color(hex: "111827") : Color(hex: "9CA3AF"))
                        )
                }
                .disabled(!isConsentGiven)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Color.white
                .shadow(color: Color.black.opacity(0.1), radius: 6, y: -2)
        )
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(hex: "E6E8EE")),
            alignment: .top
        )
    }
    
    // MARK: - Helper Functions
    private func attributedString(from text: String) -> AttributedString {
        var attributedString = AttributedString(text)
        
        // Find email pattern
        if let range = text.range(of: #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#, options: .regularExpression) {
            let email = String(text[range])
            if let attrRange = attributedString.range(of: email) {
                attributedString[attrRange].foregroundColor = Color(hex: "1F4FD6")
                attributedString[attrRange].underlineStyle = .single
                attributedString[attrRange].font = .system(size: 13, weight: .semibold)
                
                // Make it tappable
                if let url = URL(string: "mailto:\(email)") {
                    attributedString[attrRange].link = url
                }
            }
        }
        
        return attributedString
    }
}

#Preview {
    UserConsentView(onComplete: {})
}
