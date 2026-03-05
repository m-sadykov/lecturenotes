import SwiftUI

struct ProcessingView: View {
    let lectureTitle: String
    @State private var stage: LectureStatus = .uploading

    var body: some View {
        List {
            Section("Lecture") {
                Text(lectureTitle)
            }

            Section("Status") {
                ProcessingRowView(label: "Uploading", isActive: stage == .uploading)
                ProcessingRowView(label: "Transcribing", isActive: stage == .transcribing)
                ProcessingRowView(label: "Generating notes", isActive: stage == .generating)
                ProcessingRowView(label: "Ready", isActive: stage == .ready)
            }

            if stage == .ready {
                Section {
                    Text("You can close this screen and continue in Home.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Processing")
        .task {
            await runMockPipeline()
        }
    }

    private func runMockPipeline() async {
        stage = .uploading
        try? await Task.sleep(for: .seconds(1))
        stage = .transcribing
        try? await Task.sleep(for: .seconds(1))
        stage = .generating
        try? await Task.sleep(for: .seconds(1))
        stage = .ready
    }
}
