//
//  LinkedDeviceComponents.swift
//  ByoSync-User
//
//  Created by Hari's Mac on 11.11.2025.
//

import SwiftUI

// MARK: - Compact Badge
struct CompactBadge: View {
    let text: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(text)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Action Button
struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let style: ButtonActionStyle
    let action: () -> Void
    
    enum ButtonActionStyle {
        case prominent
        case destructive
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(style == .prominent ? color : Color.clear)
            )
            .foregroundColor(style == .prominent ? .white : color)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(color.opacity(style == .prominent ? 0 : 0.3), lineWidth: 2)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Security Info Card
struct SecurityInfoCard: View {
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [Color.green.opacity(0.2), Color.mint.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                Image(systemName: "lock.shield.fill")
                    .font(.title3)
                    .foregroundColor(.green)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Secure & Protected")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("Only your primary device can manage linked devices")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}

// MARK: - Session Provider
struct SessionProvider {
    private let userSession: UserSession
    
    init(userSession: UserSession) {
        self.userSession = userSession
    }
    
    private var currentDeviceID: String {
        return userSession.currentUserDeviceID
    }
    
    func isThisDevicePrimary() -> Bool {
        return userSession.thisDeviceIsPrimary
    }
    
    func isCurrentDevice(_ device: GetDeviceData) -> Bool {
        return device.id == currentDeviceID
    }
}

// MARK: - Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Info Pill
struct InfoPill: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Other Device Card
struct OtherDeviceCard: View {
    let device: GetDeviceData
    let isThisDevicePrimary: Bool
    let onMakePrimary: () -> Void
    let onUnlink: () -> Void
    
    @State private var showActions = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showActions.toggle()
                    if showActions {
                        HapticManager.impact(style: .light)
                    }
                }
            }) {
                HStack(spacing: 16) {
                    // Device icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: device.isPrimary ?
                                        [Color.blue.opacity(0.2), Color.purple.opacity(0.2)] :
                                        [Color.gray.opacity(0.1), Color.gray.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: deviceIcon)
                            .font(.system(size: 26))
                            .foregroundColor(device.isPrimary ? .blue : .gray)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(device.deviceName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 8) {
                            if device.isPrimary {
                                CompactBadge(text: "Primary", icon: "star.fill", color: .blue)
                            }
                            
                            if let lastUpdated = formatDate(device.updatedAt) {
                                CompactBadge(text: lastUpdated, icon: "clock", color: .gray)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: showActions ? "chevron.up" : "chevron.down")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(showActions ? 0 : 0))
                }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(PlainButtonStyle())
            
            // Action buttons
            if showActions {
                VStack(spacing: 10) {
                    if !device.isPrimary && isThisDevicePrimary {
                        ActionButton(
                            title: "Make Primary Device",
                            icon: "star.fill",
                            color: .blue,
                            style: .prominent,
                            action: onMakePrimary
                        )
                    }
                    
                    if isThisDevicePrimary {
                        ActionButton(
                            title: "Unlink Device",
                            icon: "trash.fill",
                            color: .red,
                            style: .destructive,
                            action: onUnlink
                        )
                    }
                }
                .padding(16)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .scale(scale: 0.95).combined(with: .opacity)
                ))
            }
        }
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
    
    private var deviceIcon: String {
        let name = device.deviceName.lowercased()
        if name.contains("iphone") {
            return "iphone.gen3"
        } else if name.contains("ipad") {
            return "ipad.gen2"
        } else if name.contains("mac") {
            return "laptopcomputer"
        } else {
            return "iphone.gen3"
        }
    }
    
    private func formatDate(_ dateString: String) -> String? {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return nil }
        
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day, .hour, .minute], from: date, to: now)
        
        if let days = components.day, days > 0 {
            return days == 1 ? "1d ago" : "\(days)d ago"
        } else if let hours = components.hour, hours > 0 {
            return hours == 1 ? "1h ago" : "\(hours)h ago"
        } else if let minutes = components.minute, minutes > 0 {
            return minutes == 1 ? "1m ago" : "\(minutes)m ago"
        } else {
            return "Now"
        }
    }
}

// MARK: - Current Device Hero Card
struct CurrentDeviceHeroCard: View {
    let device: GetDeviceData
    let isPrimary: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Top gradient section
            ZStack(alignment: .topTrailing) {
                LinearGradient(
                    colors: [Color(hex: "4B548D"),Color(hex: "4B548D")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Decorative circles
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .offset(x: 40, y: -30)
                
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 80, height: 80)
                    .offset(x: -20, y: 50)
                
                // Content
                HStack(spacing: 16) {
                    // Device icon
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 70, height: 70)
                        
                        Image(systemName: deviceIcon)
                            .font(.system(size: 35))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(device.deviceName)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        if isPrimary {
                            HStack(spacing: 6) {
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                Text("Primary Device")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.yellow)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.2))
                            )
                        } else {
                            Text("Secondary Device")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    
                    Spacer()
                }
                .padding(24)
            }
            .frame(height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            
            // Bottom info section
            HStack(spacing: 0) {
                InfoPill(
                    icon: "checkmark.shield.fill",
                    title: "Active",
                    color: .green
                )
                
                Divider()
                    .frame(height: 30)
                
                if let lastUpdated = formatDate(device.updatedAt) {
                    InfoPill(
                        icon: "clock.fill",
                        title: lastUpdated,
                        color: .blue
                    )
                }
            }
            .padding(.vertical, 16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .offset(y: -20)
        }
        .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
    }
    
    private var deviceIcon: String {
        let name = device.deviceName.lowercased()
        if name.contains("iphone") {
            return "iphone.gen3"
        } else if name.contains("ipad") {
            return "ipad.gen2"
        } else if name.contains("mac") {
            return "laptopcomputer"
        } else {
            return "iphone.gen3"
        }
    }
    
    private func formatDate(_ dateString: String) -> String? {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return nil }
        
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day, .hour, .minute], from: date, to: now)
        
        if let days = components.day, days > 0 {
            return days == 1 ? "1d ago" : "\(days)d ago"
        } else if let hours = components.hour, hours > 0 {
            return hours == 1 ? "1h ago" : "\(hours)h ago"
        } else if let minutes = components.minute, minutes > 0 {
            return minutes == 1 ? "1m ago" : "\(minutes)m ago"
        } else {
            return "Now"
        }
    }
}
