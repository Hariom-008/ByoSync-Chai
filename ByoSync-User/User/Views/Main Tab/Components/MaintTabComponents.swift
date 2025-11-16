//
//  MaintTabComponents.swift
//  ByoSync-User
//
//  Created by Hari's Mac on 11.11.2025.
//


import Foundation
import SwiftUI

// MARK: - Main Tab Enum
enum MainTab {
    case home
    case profile
}

// MARK: - Tab Item Component
struct TabItem: View {
    let systemName: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemName)
                    .font(.system(size: 22, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? Color(hex: "4B548D") : .gray)
                
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? Color(hex: "4B548D") : .gray)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(TabItemButtonStyle())
    }
}

// MARK: - Custom Button Style
struct TabItemButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
