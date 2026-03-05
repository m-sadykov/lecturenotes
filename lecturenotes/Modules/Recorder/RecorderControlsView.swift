import SwiftUI

struct RecorderControlsView: View {
    let viewModel: RecorderViewModel

    var body: some View {
        VStack {
            Button("Record", systemImage: "record.circle") {
                viewModel.record()
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.mode == .recording)

            Button("Pause", systemImage: "pause.circle") {
                viewModel.pause()
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.mode != .recording)

            Button("Resume", systemImage: "play.circle") {
                viewModel.resume()
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.mode != .paused)

            Button("Stop", systemImage: "stop.circle") {
                viewModel.stop()
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.mode == .idle || viewModel.mode == .finished)
        }
    }
}
