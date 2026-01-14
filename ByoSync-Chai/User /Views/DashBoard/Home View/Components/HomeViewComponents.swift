//
//  HomeViewComponents.swift
//  ByoSync-User
//
//  Created by Hari's Mac on 09.11.2025.
//

import Foundation
import SwiftUI

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        .clear,
                        Color.white.opacity(0.3),
                        .clear
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .mask(content)
            )
            .onAppear {
                withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 400
                }
            }
    }
}
// MARK: - Promotion Card (Enhanced)
 struct PromotionCard: View {
    var promotionTitle: String
    var promotionDescription: String
    var icon: String
    var iconColor: Color
    var accentColor: Color
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [iconColor.opacity(0.2), iconColor.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)

                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(promotionTitle)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.black)

                Text(promotionDescription)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(width: 330)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [accentColor.opacity(0.19), accentColor.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .shadow(color: accentColor.opacity(0.12), radius: 14, x: 0, y: 7)
        )
    }
}


// MARK: - Leaderboard Preview Item (Enhanced)
struct LeaderboardPreviewItem: View {
    let rank: String
    let name: String
    let score: String
    let rankColor: Color
    var isHighlighted: Bool = false
    var isFirstRank: Bool = false
    let cryptoManager = CryptoManager()
    
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(rankColor.opacity(0.4))
                    .frame(width: isFirstRank ? 58 : 32, height: isFirstRank ? 58 : 32)
                    .zIndex(0)
                
                Circle()
                    .stroke(rankColor.opacity(0.4), lineWidth: 2)
                    .frame(width: isFirstRank ? 58 : 32, height: isFirstRank ? 58 : 32)
                    .zIndex(0)
                
                Text(rank)
                    .font(.system(size: isFirstRank ? 22 : 14, weight: .bold))
                    .foregroundColor(.white)
                    .zIndex(1)
            }
            
            VStack(spacing: 3) {
                Text("\(cryptoManager.decrypt(encryptedData: name) ?? "You")")
                    .font(.system(size: 13, weight: isHighlighted ? .bold : .semibold))
                    .foregroundColor(.black)
                    .lineLimit(1)
                
                HStack{
                    Text(score)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    if isHighlighted {
                        Text("(you)")
                            .font(.caption2)
                            .foregroundStyle(.black)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .scaleEffect(isHighlighted ? 1.05 : 1.0)
    }
}
