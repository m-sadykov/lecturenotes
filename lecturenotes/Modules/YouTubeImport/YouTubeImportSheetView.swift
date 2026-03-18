import SwiftUI
import UIKit

struct YouTubeImportSheetView: View {
    let onClose: () -> Void
    let onSubmit: (String) async -> String?

    @State private var urlText = ""
    @State private var isSubmitting = false
    @State private var alertMessage: String?
    @State private var isURLFieldFocused = false
    @State private var submitFeedbackToken = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color(.systemGray6)
                .frame(height: 0)

            VStack(alignment: .leading, spacing: 18) {
                YouTubeImportHeader(onClose: onClose)

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
                    isFocused: $isURLFieldFocused
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 16)
        .background(Color(.systemGray6))
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
            .background(Color(.systemGray6))
        }
        .task {
            isURLFieldFocused = true
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

    private var trimmedURL: String {
        urlText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func submit() {
        guard !trimmedURL.isEmpty, !isSubmitting else {
            return
        }

        guard let url = URL(string: trimmedURL), let host = url.host() else {
            alertMessage = "Enter a valid YouTube link."
            return
        }

        let lowercasedHost = host.lowercased()
        guard lowercasedHost.contains("youtube.com") || lowercasedHost.contains("youtu.be") else {
            alertMessage = "Enter a valid YouTube link."
            return
        }

        if url.path().localizedStandardContains("/shorts/") {
            alertMessage = "YouTube Shorts are not supported yet."
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

private struct YouTubeImportHeader: View {
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Text("YouTube Import")
                .font(.headline)

            HStack {
                Button(action: onClose) {
                    Label("Close", systemImage: "xmark")
                        .labelStyle(.iconOnly)
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)

                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct YouTubeURLField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isFocused: $isFocused)
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

        if isFocused, !textField.isFirstResponder {
            textField.becomeFirstResponder()
        } else if !isFocused, textField.isFirstResponder {
            textField.resignFirstResponder()
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding private var text: String
        @Binding private var isFocused: Bool

        init(text: Binding<String>, isFocused: Binding<Bool>) {
            _text = text
            _isFocused = isFocused
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            isFocused = true
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            isFocused = false
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
