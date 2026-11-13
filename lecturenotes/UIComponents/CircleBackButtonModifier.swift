import SwiftUI

/// Replaces the system back button with a `ToolbarCircleIcon` chevron, so pushed screens
/// match the circular buttons used elsewhere in the app.
private struct CircleBackButtonModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        ToolbarCircleIcon(systemImage: "chevron.left")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Back"))
                }
                .hiddenSharedBackground()
            }
    }
}

extension View {
    /// Shows a circular back button in place of the system one.
    func circleBackButton() -> some View {
        modifier(CircleBackButtonModifier())
    }
}
