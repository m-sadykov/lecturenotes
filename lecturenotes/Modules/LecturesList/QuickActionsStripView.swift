import SwiftUI

struct QuickActionsStripView: View {
    let onImportRecording: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            QuickActionButtonView(title: "Import Recording", systemImage: "square.and.arrow.down", action: onImportRecording)
            QuickActionButtonView(title: "Text Import", systemImage: "doc.text", action: {})
            QuickActionButtonView(title: "YouTube Import", systemImage: "play.rectangle", action: {})
            QuickActionButtonView(title: "PDF Import", systemImage: "doc.richtext", action: {})
        }
    }
}
