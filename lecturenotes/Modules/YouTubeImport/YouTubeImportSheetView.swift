import SwiftUI
import UIKit

struct YouTubeImportSheetView: View {
    let onClose: () -> Void
    let onSubmit: (String) async -> String?

    @State private var urlText = ""
    @State private var isSubmitting = false
    @State private var alertMessage: String?
    @State private var autofocusTrigger = 0
    @State private var submitFeedbackToken = 0

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                Color(.systemGray6)
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
                    .background(.white)
                    .clipShape(.rect(cornerRadius: 20))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(.black.opacity(0.05), lineWidth: 1)
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
                                    .tint(.white)
                            }

                            Text(isSubmitting ? "Sending..." : "Send")
                                .bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.black)
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
                    get: { alertMessage != nil },
                    set: { isPresented in
                        if !isPresented {
                            alertMessage = nil
                        }
                    }
                )
            ) {
                Button("OK") {
                    alertMessage = nil
                }
            } message: {
                Text(alertMessage ?? "")
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
        alertMessage = nil

        Task {
            let errorMessage = await onSubmit(trimmedURL)

            await MainActor.run {
                if let errorMessage {
                    alertMessage = errorMessage
                    isSubmitting = false
                }
            }
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
        textField.attributedPlaceholder = NSAttributedString(
            string: "https://www.youtube.com/watch?v=...",
            attributes: [
                .foregroundColor: UIColor.placeholderText,
            ]
        )
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
        context.coordinator.attach(to: textField)
        context.coordinator.handleAutofocusTrigger(autofocusTrigger)
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
