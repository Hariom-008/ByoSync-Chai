//
//  SplashScreenView.swift
//  ByoSync-User
//
//  Created by Hari's Mac on 30.12.2025.
//

import Foundation
import SwiftUI
// Enhanced splash screen with smooth animations
struct SplashScreenView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(UIColor.systemGroupedBackground),
                    Color(UIColor.secondarySystemGroupedBackground)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Animated progress indicator
               Image("logo")
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(isAnimating ? 1.0 : 0.9, anchor: .center)
                    .frame(width: 120,height: 120)
                    .padding(.bottom, 40)
            }
            .padding()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

