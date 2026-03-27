import SwiftUI
import UIKit

struct MiniRecorderSheetView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var viewModel: RecorderViewModel
    let onSave: (RecorderViewModel.RecordingDraft) -> Void
    let onClose: () -> Void
    @State private var feedbackTrigger = 0

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
        .onAppear {
            updateIdleTimer()
        }
        .onChange(of: viewModel.mode, initial: true) { _, _ in
            updateIdleTimer()
        }
        .onChange(of: scenePhase, initial: true) { _, newPhase in
            switch newPhase {
            case .background:
                viewModel.handleAppDidEnterBackground()
            case .active:
                viewModel.handleAppDidBecomeActive()
            case .inactive:
                break
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .sensoryFeedback(.impact(weight: .light), trigger: feedbackTrigger)
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
                triggerFeedback()
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
                triggerFeedback()
                if let recording = viewModel.finishRecording() {
                    onSave(recording)
                }
                onClose()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 84, height: 84)
                    .background(Color(red: 0.88, green: 0.33, blue: 0.33))
                    .clipShape(.circle)
                    .shadow(color: Color.red.opacity(0.18), radius: 14, y: 6)
            }
            .buttonStyle(.plain)

            Button {
                triggerFeedback()
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

    private func triggerFeedback() {
        feedbackTrigger += 1
    }

    private func updateIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = switch viewModel.mode {
        case .recording, .paused:
            true
        case .idle, .finished:
            false
        }
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()

        MiniRecorderSheetView(viewModel: RecorderViewModel(), onSave: { _ in }, onClose: {})
    }
}
