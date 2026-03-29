import SwiftUI

struct RecorderControlsView: View {
    let viewModel: RecorderViewModel

    var body: some View {
        VStack {
            Button("Record", systemImage: "record.circle") {
                Task {
                    await viewModel.start()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.mode == .recording)

            if viewModel.mode == .paused {
                Button("Resume", systemImage: "play.circle") {
                    viewModel.togglePause()
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.canTogglePause)
            } else {
                Button("Pause", systemImage: "pause.circle") {
                    viewModel.togglePause()
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.canTogglePause)
            }

            Button("Stop", systemImage: "stop.circle") {
                viewModel.stop()
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.mode == .idle || viewModel.mode == .finished)
        }
    }
}
