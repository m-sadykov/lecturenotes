import SwiftUI

struct MiniRecorderSheetView: View {
    @Bindable var viewModel: RecorderViewModel
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(.secondary.opacity(0.35))
                .frame(width: 44, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 28)

            VStack(alignment: .leading, spacing: 32) {
                header
                progressSection
                controlRow
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .frame(minHeight: 340, alignment: .top)
        .background(.thinMaterial)
        .clipShape(.rect(topLeadingRadius: 28, topTrailingRadius: 28))
        .shadow(color: .black.opacity(0.18), radius: 20, y: -4)
        .ignoresSafeArea(edges: .bottom)
        .task {
            await viewModel.start()
        }
        .alert("Recording Error", isPresented: errorBinding) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Новая запись")
                    .font(.title3)
                    .bold()
                Text(statusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(LectureFormatters.clockText(viewModel.elapsed)) / \(LectureFormatters.clockText(viewModel.limit))")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            ProgressView(value: viewModel.progress)
                .progressViewStyle(.linear)
                .tint(progressTint)
        }
        .padding(.top, 4)
    }

    private var controlRow: some View {
        HStack(spacing: 18) {
            Button {
                viewModel.stopAndDiscard()
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundStyle(.primary)
                    .frame(width: 56, height: 56)
                    .background(.regularMaterial)
                    .clipShape(.circle)
                    .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
            }
            .buttonStyle(.plain)

            Button {
                viewModel.stopAndDiscard()
                onClose()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 84, height: 84)
                    .background(Color.red)
                    .clipShape(.circle)
                    .shadow(color: .red.opacity(0.3), radius: 18, y: 8)
            }
            .buttonStyle(.plain)

            Button {
                viewModel.togglePause()
            } label: {
                Image(systemName: viewModel.mode == .paused ? "play.fill" : "pause.fill")
                    .font(.title2)
                    .foregroundStyle(.primary)
                    .frame(width: 56, height: 56)
                    .background(.regularMaterial)
                    .clipShape(.circle)
                    .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canTogglePause)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
    }

    private var progressTint: Color {
        viewModel.mode == .paused ? .orange : .red
    }

    private var statusText: String {
        switch viewModel.mode {
        case .idle:
            "Подготовка"
        case .recording:
            "Запись"
        case .paused:
            "На паузе"
        case .finished:
            "Завершено"
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.errorMessage = nil
                }
            }
        )
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()

        MiniRecorderSheetView(viewModel: RecorderViewModel(), onClose: {})
    }
}
