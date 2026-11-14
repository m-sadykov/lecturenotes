import SwiftUI

/// Toolbar menu that groups every way to add content other than recording.
struct HomeImportMenu: View {
    let onImportRecording: () -> Void
    let onImportText: () -> Void
    let onImportYouTube: () -> Void
    let onImportPDF: () -> Void

    var body: some View {
        Menu("Import", systemImage: "square.and.arrow.down") {
            Button("Import Recording", systemImage: "waveform", action: onImportRecording)
            Button("Text Import", systemImage: "doc.text", action: onImportText)
            Button("YouTube Import", systemImage: "play.rectangle", action: onImportYouTube)
            Button("PDF Import", systemImage: "doc.richtext", action: onImportPDF)
        }
    }
}
