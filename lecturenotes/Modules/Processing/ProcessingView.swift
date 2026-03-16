import SwiftUI

struct ProcessingView: View {
    let lecture: Lecture

    var body: some View {
        List {
            Section("Lecture") {
                VStack(alignment: .leading, spacing: 6) {
                    Text(lecture.title)
                    Text(statusMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Status") {
                ProcessingRowView(label: "Uploading", state: rowState(for: .uploading))
                ProcessingRowView(label: "Transcribing", state: rowState(for: .transcribing))
                ProcessingRowView(label: "Generating notes", state: rowState(for: .generating))
                ProcessingRowView(label: "Ready", state: rowState(for: .ready))
            }

            if lecture.status == .failed {
                Section("Problem") {
                    Text(lecture.processingErrorMessage ?? "We couldn't process this recording.")
                        .foregroundStyle(.secondary)
                }
            }

            if lecture.status == .ready {
                Section {
                    Text("Your notes are ready.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Processing")
        .scrollContentBackground(.hidden)
        .background(Color(.systemGray6))
    }

    private var statusMessage: String {
        switch lecture.status {
        case .draft:
            "Preparing your recording."
        case .uploading:
            "Uploading your recording."
        case .transcribing:
            "Transcribing speech into text."
        case .generating:
            "Generating title, summary, flashcards, and quiz."
        case .ready:
            "Processing finished successfully."
        case .failed:
            "Processing failed."
        }
    }

    private func rowState(for stage: LectureStatus) -> ProcessingRowView.State {
        if lecture.status == .failed {
            return hasCompleted(stage) ? .completed : .idle
        }

        if lecture.status == stage {
            return stage == .ready ? .completed : .active
        }

        return hasCompleted(stage) ? .completed : .idle
    }

    private func hasCompleted(_ stage: LectureStatus) -> Bool {
        stageOrderIndex(for: lecture.status) > stageOrderIndex(for: stage)
    }

    private func stageOrderIndex(for stage: LectureStatus) -> Int {
        switch stage {
        case .draft:
            0
        case .uploading:
            1
        case .transcribing:
            2
        case .generating:
            3
        case .ready:
            4
        case .failed:
            4
        }
    }
}
