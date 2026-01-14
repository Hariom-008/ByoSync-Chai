//
//  FormField.swift
//  ByoSync-User
//
//  Created by Hari's Mac on 10.12.2025.
//

import SwiftUI

// MARK: - Form Field Component
struct FormField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.indigo)
                    .frame(width: 24)
                
                TextField(placeholder, text: $text)
                    .font(.system(size: 16, weight: .regular, design: .default))
                    .keyboardType(keyboardType)
                    .autocapitalization(keyboardType == .emailAddress ? .none : .words)
                    .textContentType(contentTypeForKeyboard(keyboardType))
                    .focused($isFocused)
                    .disabled(icon == "phone.fill")
                
                if !text.isEmpty {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.green)
                        .transition(.scale)
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isFocused ?
                          Color.black
                        : Color.clear,
                        lineWidth: 0.5
                    )
            )
            .shadow(color: isFocused ? .indigo.opacity(0.1) : .clear, radius: 8, x: 0, y: 4)
            .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
    }
    
    private func contentTypeForKeyboard(_ type: UIKeyboardType) -> UITextContentType? {
        switch type {
        case .emailAddress:
            return .emailAddress
        case .phonePad:
            return .telephoneNumber
        default:
            return nil
        }
    }
}
