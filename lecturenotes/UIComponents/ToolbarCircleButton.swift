import SwiftUI

/// Toolbar button drawn as a `ToolbarCircleIcon`, with a text label for VoiceOver.
/// Place it in a toolbar item that uses `hiddenSharedBackground()`.
struct ToolbarCircleButton: View {
    let title: LocalizedStringKey
    let systemImage: String
    let action: () -> Void

    init(_ title: LocalizedStringKey, systemImage: String, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ToolbarCircleIcon(systemImage: systemImage)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
    }
}
