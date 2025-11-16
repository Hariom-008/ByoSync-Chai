//
//  LogsTestingView.swift
//  ByoSync-User
//
//  Created by Hari's Mac on 12.11.2025.
//

import SwiftUI

struct LogsTestingView: View {
    @State private var pendingLogCount: Int = 0
    @State private var isSending: Bool = false
    @State private var showSuccessMessage: Bool = false
    @State private var showErrorMessage: Bool = false
    @State private var statusMessage: String = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "F8F9FD"),
                        Color(hex: "EEF0F8")
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header Card
                        headerCard
                        
                        // Stats Card
                        statsCard
                        
                        // Action Buttons
                        actionButtons
                        
                        // Test Log Buttons
                        testLogSection
                        
                        // Status Messages
                        if showSuccessMessage {
                            successBanner
                        }
                        
                        if showErrorMessage {
                            errorBanner
                        }
                    }
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text("Logs Testing")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        refreshLogCount()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "4B548D"))
                    }
                }
            }
            .onAppear {
                refreshLogCount()
            }
        }
    }
    
    // MARK: - Header Card
    private var headerCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "4B548D").opacity(0.2), Color(hex: "6B74A8").opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "4B548D"), Color(hex: "6B74A8")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 8) {
                Text("Logger Control Panel")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Manage and test application logs")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 10, y: 5)
    }
    
    // MARK: - Stats Card
    private var statsCard: some View {
        HStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("\(pendingLogCount)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "4B548D"), Color(hex: "6B74A8")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Pending Logs")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(
                LinearGradient(
                    colors: [Color(hex: "4B548D").opacity(0.05), Color(hex: "6B74A8").opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
            
            VStack(spacing: 8) {
                Text("20")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.orange)
                
                Text("Batch Size")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(Color.orange.opacity(0.05))
            .cornerRadius(16)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 10, y: 5)
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Push Logs Button
            Button(action: pushLogsToBackend) {
                HStack(spacing: 12) {
                    if isSending {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 20))
                    }
                    
                    Text(isSending ? "Sending Logs..." : "Push Logs to Backend")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "4B548D"),
                            Color(hex: "6B74A8")
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(14)
                .shadow(color: Color(hex: "4B548D").opacity(0.3), radius: 12, y: 6)
            }
            .disabled(isSending || pendingLogCount == 0)
            .opacity(pendingLogCount == 0 ? 0.5 : 1.0)
            
            // Clear Logs Button
            Button(action: clearAllLogs) {
                HStack(spacing: 12) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 18))
                    
                    Text("Clear All Logs")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.red.opacity(0.1))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
            }
            .disabled(isSending)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 10, y: 5)
    }
    
    // MARK: - Test Log Section
    private var testLogSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .foregroundColor(Color(hex: "4B548D"))
                Text("Test Logs")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            VStack(spacing: 10) {
                testLogButton(
                    title: "Verbose Log",
                    icon: "text.bubble.fill",
                    color: .purple,
                    action: { generateTestLog(level: .verbose) }
                )
                
                testLogButton(
                    title: "Debug Log",
                    icon: "ladybug.fill",
                    color: .blue,
                    action: { generateTestLog(level: .debug) }
                )
                
                testLogButton(
                    title: "Info Log",
                    icon: "info.circle.fill",
                    color: .green,
                    action: { generateTestLog(level: .info) }
                )
                
                testLogButton(
                    title: "Warning Log",
                    icon: "exclamationmark.triangle.fill",
                    color: .orange,
                    action: { generateTestLog(level: .warning) }
                )
                
                testLogButton(
                    title: "Error Log",
                    icon: "xmark.circle.fill",
                    color: .red,
                    action: { generateTestLog(level: .error) }
                )
                
                testLogButton(
                    title: "Critical Log",
                    icon: "flame.fill",
                    color: .red,
                    action: { generateTestLog(level: .critical) }
                )
                
                Divider()
                    .padding(.vertical, 4)
                
                testLogButton(
                    title: "Test Middleware Call",
                    icon: "arrow.right.circle.fill",
                    color: Color(hex: "4B548D"),
                    action: testMiddlewareCall
                )
                
                testLogButton(
                    title: "Test API Call",
                    icon: "network",
                    color: .cyan,
                    action: testApiCall
                )
                
                testLogButton(
                    title: "Test Bad Request",
                    icon: "exclamationmark.octagon.fill",
                    color: .orange,
                    action: testBadRequest
                )
                
                testLogButton(
                    title: "Test Success",
                    icon: "checkmark.seal.fill",
                    color: .green,
                    action: testSuccess
                )
                
                Divider()
                    .padding(.vertical, 4)
                
                testLogButton(
                    title: "Generate 10 Logs",
                    icon: "square.stack.3d.up.fill",
                    color: Color(hex: "4B548D"),
                    action: generate10Logs
                )
                
                testLogButton(
                    title: "Generate 25 Logs (Trigger Batch)",
                    icon: "square.stack.3d.up.badge.automatic.fill",
                    color: .orange,
                    action: generate25Logs
                )
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 10, y: 5)
    }
    
    private func testLogButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(color.opacity(0.05))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Success Banner
    private var successBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.green)
            
            Text(statusMessage)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.green)
            
            Spacer()
        }
        .padding(16)
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    // MARK: - Error Banner
    private var errorBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.red)
            
            Text(statusMessage)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.red)
            
            Spacer()
        }
        .padding(16)
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    // MARK: - Actions
    private func refreshLogCount() {
        pendingLogCount = Logger.shared.getPendingLogCount()
        Logger.shared.apiCall("Log count refreshed: \(pendingLogCount) pending")
    }
    
    private func pushLogsToBackend() {
        guard pendingLogCount > 0 else {
            showMessage("No logs to send", isError: true)
            return
        }
        
        isSending = true
        Logger.shared.middlewareCall("Manual log flush initiated from testing view")
        
        // Flush logs
        Logger.shared.flushLogs()
        
        // Wait a bit for the async operation to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isSending = false
            refreshLogCount()
            Logger.shared.middlewareSuccess("Logs successfully flushed to backend")
            showMessage("Logs sent to backend successfully!", isError: false)
        }
    }
    
    private func clearAllLogs() {
        Logger.shared.clearAllLogs()
        refreshLogCount()
        Logger.shared.success("All logs cleared from storage")
        showMessage("All logs cleared", isError: false)
    }
    
    private func generateTestLog(level: LogLevel) {
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        
        switch level {
        case .verbose:
            Logger.shared.verbose("Test verbose log generated at \(timestamp)")
        case .debug:
            Logger.shared.debug("Test debug log generated at \(timestamp)")
        case .info:
            Logger.shared.info("Test info log generated at \(timestamp)")
        case .warning:
            Logger.shared.warning("Test warning log generated at \(timestamp)")
        case .error:
            Logger.shared.error("Test error log generated at \(timestamp)")
        case .critical:
            Logger.shared.critical("Test critical log generated at \(timestamp)")
        }
        
        refreshLogCount()
        showMessage("\(level.name) log generated", isError: false)
    }
    
    private func testMiddlewareCall() {
        Logger.shared.middlewareCall("Testing middleware authentication check")
        Logger.shared.middlewareSuccess("Middleware authentication passed")
        refreshLogCount()
        showMessage("Middleware logs generated", isError: false)
    }
    
    private func testApiCall() {
        Logger.shared.apiCall("GET /api/users - Fetching user list")
        Logger.shared.apiCall("POST /api/auth/login - User authentication")
        refreshLogCount()
        showMessage("API call logs generated", isError: false)
    }
    
    private func testBadRequest() {
        Logger.shared.badRequest("Invalid email format provided")
        Logger.shared.badRequest("Missing required field: password")
        refreshLogCount()
        showMessage("Bad request logs generated", isError: false)
    }
    
    private func testSuccess() {
        Logger.shared.success("User profile updated successfully")
        Logger.shared.success("Data synchronization completed")
        refreshLogCount()
        showMessage("Success logs generated", isError: false)
    }
    
    private func generate10Logs() {
        for i in 1...10 {
            let logTypes: [LogType] = [.apiCall, .success, .middlewareCall, .middlewareSuccess]
            let randomType = logTypes.randomElement() ?? .apiCall
            Logger.shared.log("Bulk test log #\(i) generated", level: .info, type: randomType)
        }
        refreshLogCount()
        showMessage("10 logs generated successfully", isError: false)
    }
    
    private func generate25Logs() {
        for i in 1...25 {
            let logTypes: [LogType] = [.apiCall, .success, .middlewareCall, .middlewareSuccess, .badRequest]
            let levels: [LogLevel] = [.info, .debug, .warning]
            let randomType = logTypes.randomElement() ?? .apiCall
            let randomLevel = levels.randomElement() ?? .info
            Logger.shared.log("Batch trigger test log #\(i)", level: randomLevel, type: randomType)
        }
        refreshLogCount()
        showMessage("25 logs generated - batch should auto-send!", isError: false)
    }
    
    private func showMessage(_ message: String, isError: Bool) {
        statusMessage = message
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if isError {
                showErrorMessage = true
                showSuccessMessage = false
            } else {
                showSuccessMessage = true
                showErrorMessage = false
            }
        }
        
        // Hide message after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showSuccessMessage = false
                showErrorMessage = false
            }
        }
    }
}

#Preview {
    LogsTestingView()
}
