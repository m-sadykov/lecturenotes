import SwiftUI

/// Adds the "New Set" toolbar button to the flashcards and quiz screens, with the
/// confirmation before replacing the set, a progress overlay and the error alert.
private struct StudyItemsRegenerationModifier<Item: Sendable>: ViewModifier {
    @Bindable var model: StudyItemsRegenerationModel<Item>
    /// `false` where the screen offers its own "New Set" button, like the quiz results.
    let showsToolbarButton: Bool
    let onGenerate: () async -> Void

    func body(content: Content) -> some View {
        content
            .toolbar {
                if model.isOffered && showsToolbarButton {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("New Set", systemImage: "arrow.clockwise", action: model.requestNewSet)
                            .labelStyle(.iconOnly)
                            .foregroundStyle(.primary)
                            .disabled(model.isRegenerating)
                    }
                }
            }
            .overlay {
                if model.isRegenerating {
                    StudyItemsRegenerationProgressView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: model.isRegenerating)
            .alert("Replace the current set?", isPresented: $model.isConfirmationPresented) {
                Button("Cancel", role: .cancel) {}
                Button("Generate") {
                    Task {
                        await onGenerate()
                    }
                }
            } message: {
                Text("A new set will be generated from this lecture and replace the current one.")
            }
            .alert("New Set", isPresented: $model.isErrorPresented, presenting: model.error) { _ in
                Button("OK", role: .cancel) {}
            } message: { error in
                Text(error.errorDescription ?? "")
            }
    }
}

/// Dims the screen while a new set is generated, which takes several seconds.
private struct StudyItemsRegenerationProgressView: View {
    var body: some View {
        ZStack {
            AppColor.overlayScrim
                .ignoresSafeArea()

            ProgressView("Generating a new set…")
                .padding(24)
                .background(AppColor.surface, in: .rect(cornerRadius: 20))
        }
    }
}

extension View {
    func studyItemsRegeneration<Item: Sendable>(
        _ model: StudyItemsRegenerationModel<Item>,
        showsToolbarButton: Bool = true,
        onGenerate: @escaping () async -> Void
    ) -> some View {
        modifier(StudyItemsRegenerationModifier(model: model, showsToolbarButton: showsToolbarButton, onGenerate: onGenerate))
    }
}
