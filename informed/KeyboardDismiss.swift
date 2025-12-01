import SwiftUI

// MARK: - Keyboard Dismissal Utilities

/// Extension to hide the keyboard programmatically
extension View {
    /// Hides the keyboard when called
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    /// Adds a tap gesture to dismiss the keyboard when tapping outside text fields
    func dismissKeyboardOnTap() -> some View {
        self.modifier(DismissKeyboardOnTap())
    }
}

/// View modifier that adds tap gesture to dismiss keyboard
private struct DismissKeyboardOnTap: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
    }
}
