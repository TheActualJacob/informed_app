//
//  SearchBar.swift
//  informed
//
//  Reusable search bar component with link detection
//

import SwiftUI

struct SearchBarView: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    @Environment(\.colorScheme) var colorScheme
    
    private var isValidURL: Bool {
        guard let url = URL(string: text),
              url.scheme != nil,
              url.host != nil else {
            return false
        }
        return true
    }
    
    var body: some View {
        HStack {
            Image(systemName: isValidURL ? "link.circle.fill" : "magnifyingglass")
                .foregroundColor(isValidURL ? .brandGreen : .brandBlue)
            
            TextField("Paste a link or search...", text: $text)
                .foregroundColor(.primary)
                .focused($isFocused)
                .submitLabel(.done)
                .onSubmit {
                    isFocused = false
                }
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                    HapticManager.lightImpact()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(Theme.CornerRadius.lg)
        .shadow(
            color: Theme.Shadow.card(for: colorScheme),
            radius: Theme.Shadow.sm,
            x: 0,
            y: 2
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .stroke(isValidURL ? Color.brandGreen : Color.clear, lineWidth: 2)
        )
        .animation(Theme.Animation.quick, value: isValidURL)
    }
}
