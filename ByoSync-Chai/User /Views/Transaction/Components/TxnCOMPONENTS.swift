//
//  TxnComponents.swift
//  ByoSync-User
//
//  Created by Hari's Mac on 11.11.2025.
//

import Foundation
import SwiftUI

// MARK: - Report Type
enum ReportType: String, CaseIterable {
    case view = "view"
    
    var displayName: String {
        switch self {
        case .view:
            return "View"
        }
    }
    
    var iconName: String {
        switch self {
        case .view:
            return "eye.fill"
        }
    }
    
    var buttonText: String {
        switch self {
        case .view:
            return "View Report"
        }
    }
}


struct TransactionRow: View {
    @EnvironmentObject var cryptoManager: CryptoManager
    let transaction: Transaction
    
    private var receiver: TxUser? {
        transaction.receiverId
    }
    
    private var currentUser: Bool {
        UserSession.shared.currentUser?.userId == receiver?.id
    }
    
    var body: some View {
        HStack(spacing: 12) {
            
            // Profile Image
            AsyncImage(url: profileImageURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Circle()
                    .fill(Color(hex: "4B548D").opacity(0.1))
                    .overlay(
                        Text(initialLetter)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "4B548D"))
                    )
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())
            
            // Transaction Details
            VStack(alignment: .leading, spacing: 4) {
                
                // Decrypted Name
                HStack(spacing: 4) {
                    Text(decrypted(receiver?.firstName))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(decrypted(receiver?.lastName))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                HStack(spacing: 8) {
                    Text(currentUser ? "Received" : "Sent")
                        .font(.caption2)
                        .foregroundColor(currentUser ? .green : .secondary)
                    
                    Circle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 3, height: 3)
                    
                    Text(formattedDate(transaction.createdAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Amount & Status
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(currentUser ? "+" : "-")\(transaction.coins ?? 0)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(currentUser ? .green : .red)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    
                    Text(transaction.status.capitalized)
                        .font(.caption2)
                        .foregroundColor(statusColor)
                }
            }
        }
        .padding(12)
        .background(Color(hex: "F8F9FD"))
        .cornerRadius(12)
    }
    
    private var profileImageURL: URL? {
        guard let urlString = receiver?.userProfilePic else { return nil }
        return URL(string: urlString)
    }
    
    private var initialLetter: String {
        let first = receiver?.firstName.first.map { String($0) } ?? "?"
        return first
    }
    
    private var statusColor: Color {
        transaction.status.uppercased() == "SUCCESS" ? .green : .orange
    }
    
    private func decrypted(_ value: String?) -> String {
        guard let value else { return "-" }
        return cryptoManager.decrypt(encryptedData: value) ?? "-"
    }
    
    private func formattedDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMM dd, h:mm a"
        return displayFormatter.string(from: date)
    }
}


struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

//MARK: - Summary Card
struct CompactSummaryCard: View {
    var icon: String
    var title: String
    var value: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(.white.opacity(0.9))
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}


// MARK: - Supporting Views

struct StatCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
                    .frame(width: 36, height: 36)
                    .background(iconColor.opacity(0.1))
                    .cornerRadius(8)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
    }
}
