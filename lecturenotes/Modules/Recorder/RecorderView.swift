import SwiftUI

struct RecorderView: View {
    @State var viewModel: RecorderViewModel

    var body: some View {
        Form {
            Section("Lecture") {
                TextField("Course", text: $viewModel.courseName)
            }

            Section("Timer") {
                Text(LectureFormatters.durationText(viewModel.elapsed))
                    .bold()
                Text("Limit: \(LectureFormatters.durationText(viewModel.limit))")
                    .foregroundStyle(.secondary)
            }

            Section("Controls") {
                RecorderControlsView(viewModel: viewModel)
            }

            if viewModel.mode == .finished {
                Section {
                    NavigationLink {
                        ProcessingView(
                            lecture: Lecture(
                                title: "\(viewModel.courseName) lecture",
                                course: viewModel.courseName,
                                createdAt: .now,
                                duration: viewModel.elapsed,
                                status: .uploading,
                                transcript: "",
                                summaryShort: "",
                                summaryLong: "",
                                flashcards: [],
                                quiz: []
                            )
                        )
                    } label: {
                        Label("Continue to Processing", systemImage: "arrow.right.circle")
                    }
                }
            }
        }
        .navigationTitle("Recorder")
    }
}

#Preview {
    NavigationStack {
        RecorderView(viewModel: RecorderViewModel())
    }
}
