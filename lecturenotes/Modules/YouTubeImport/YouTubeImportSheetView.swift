import SwiftUI
import UIKit

struct YouTubeImportSheetView: View {
    @Environment(AppState.self) private var appState
    let onClose: () -> Void
    let onSubmit: (String) async -> YouTubeImportAlertError?

    @State private var urlText = ""
    @State private var isSubmitting = false
    @State private var alertError: YouTubeImportAlertError?
    @State private var autofocusTrigger = 0
    @State private var submitFeedbackToken = 0

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                AppColor.canvas
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Paste a YouTube link")
                            .font(.title3)
                            .bold()

                        Text("We'll try to fetch the transcript from YouTube captions and then generate the study pack.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    YouTubeURLField(
                        text: $urlText,
                        autofocusTrigger: autofocusTrigger
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(AppColor.surface)
                    .clipShape(.rect(cornerRadius: 20))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(AppColor.hairline, lineWidth: 1)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("How it works")
                            .font(.headline)

                        Text("We save the YouTube source metadata, fetch captions, and then generate the summary, flashcards, and quiz.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .navigationTitle("YouTube Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 10) {
                    Button {
                        submitFeedbackToken += 1
                        submit()
                    } label: {
                        HStack(spacing: 10) {
                            if isSubmitting {
                                ProgressView()
                                    .tint(AppColor.onInk)
                            }

                            if isSubmitting {
                                Text("Sending...")
                                    .bold()
                            } else {
                                Text("Send")
                                    .bold()
                            }
                        }
                        .foregroundStyle(AppColor.onInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppColor.ink, in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .opacity(trimmedURL.isEmpty || isSubmitting ? 0.45 : 1)
                    .disabled(trimmedURL.isEmpty || isSubmitting)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 12)
                .background(.ultraThinMaterial)
            }
            .onAppear {
                autofocusTrigger += 1
            }
            .alert(
                "YouTube Import",
                isPresented: Binding(
                    get: { alertError != nil },
                    set: { isPresented in
                        if !isPresented {
                            alertError = nil
                        }
                    }
                )
            ) {
                Button("OK") {
                    alertError = nil
                }
            } message: {
                Text(alertError?.message ?? "")
            }
            .onChange(of: appState.selectedLanguage, initial: false) { _, _ in
                refreshPresentedAlertIfNeeded()
            }
            .sensoryFeedback(.impact(weight: .light), trigger: submitFeedbackToken)
        }
    }

    private var trimmedURL: String {
        urlText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func submit() {
        guard !trimmedURL.isEmpty, !isSubmitting else {
            return
        }

        isSubmitting = true
        alertError = nil

        Task {
            let error = await onSubmit(trimmedURL)

            await MainActor.run {
                if let error {
                    alertError = error
                    isSubmitting = false
                }
            }
        }
    }

    private func refreshPresentedAlertIfNeeded() {
        guard let currentAlertError = alertError else {
            return
        }

        alertError = nil

        Task { @MainActor in
            alertError = currentAlertError
        }
    }
}

enum YouTubeImportAlertError: Equatable {
    case invalidLink
    case processingLimitReached(remainingCount: Int, plan: AppUserPlan)
    case saveFailed

    var message: String {
        switch self {
        case .invalidLink:
            String(localized: "Enter a valid YouTube link.")
        case .processingLimitReached(let remainingCount, let plan):
            String(localized: "You have \(remainingCount) processing attempts left on your \(plan.title) plan.")
        case .saveFailed:
            String(localized: "Unable to save YouTube import right now.")
        }
    }
}

private struct YouTubeURLField: UIViewRepresentable {
    @Binding var text: String
    let autofocusTrigger: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.borderStyle = .none
        textField.font = .preferredFont(forTextStyle: .body)
        textField.adjustsFontForContentSizeCategory = true
        textField.keyboardType = .URL
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.clearButtonMode = .whileEditing
        textField.textColor = .label
        textField.tintColor = .label
        updatePlaceholder(for: textField)
        textField.textContentType = nil
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 1))
        textField.leftViewMode = .always
        textField.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 1))
        textField.rightViewMode = .always
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return textField
    }

    func updateUIView(_ textField: UITextField, context: Context) {
        if textField.text != text {
            textField.text = text
        }
        updatePlaceholder(for: textField)
        context.coordinator.attach(to: textField)
        context.coordinator.handleAutofocusTrigger(autofocusTrigger)
    }

    private func updatePlaceholder(for textField: UITextField) {
        textField.attributedPlaceholder = NSAttributedString(
            string: String(localized: "https://www.youtube.com/watch?v=..."),
            attributes: [
                .foregroundColor: UIColor.placeholderText,
            ]
        )
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding private var text: String
        private weak var textField: UITextField?
        private var lastAutofocusTrigger = 0

        init(text: Binding<String>) {
            _text = text
        }

        func attach(to textField: UITextField) {
            self.textField = textField
        }

        func handleAutofocusTrigger(_ autofocusTrigger: Int) {
            guard autofocusTrigger != lastAutofocusTrigger else {
                return
            }

            lastAutofocusTrigger = autofocusTrigger

            Task { @MainActor [weak textField] in
                guard let textField, !textField.isFirstResponder else {
                    return
                }

                textField.becomeFirstResponder()
            }
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            text = textField.text ?? ""
        }

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            guard let currentText = textField.text,
                  let textRange = Range(range, in: currentText) else {
                return true
            }

            text = currentText.replacingCharacters(in: textRange, with: string)
            return true
        }
    }
}

#Preview {
    YouTubeImportSheetView(onClose: {}, onSubmit: { _ in nil })
}
