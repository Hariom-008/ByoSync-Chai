//
//  ScaleButtonStyle.swift
//  ByoSync-User
//
//  Created by Hari's Mac on 17.12.2025.
//

import Foundation
import SwiftUI
//// MARK: - Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
