import SwiftUI

/// First-run state of the home screen: points to the mic button and offers the import options
/// that otherwise live in the toolbar menu.
struct EmptyLecturesPlaceholderView: View {
    let onImportRecording: () -> Void
    let onImportText: () -> Void
    let onImportYouTube: () -> Void
    let onImportPDF: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            ContentUnavailableView {
                Text("No recordings yet")
            } description: {
                Text("Tap the mic button to start recording.")
            }

            QuickActionsStripView(
                onImportRecording: onImportRecording,
                onImportText: onImportText,
                onImportYouTube: onImportYouTube,
                onImportPDF: onImportPDF
            )
        }
    }
}
