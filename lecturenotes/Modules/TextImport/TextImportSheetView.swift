import SwiftUI
import UIKit

struct TextImportSheetView: View {
    let onClose: () -> Void
    let onSubmit: (String) async -> String?

    @State private var text = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var autofocusTrigger = 0
    @State private var submitFeedbackToken = 0
    @State private var pasteTrigger = 0
    @State private var selectAllTrigger = 0

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                Color(.systemGray6)
                    .ignoresSafeArea()

                TextImportEditorView(
                    text: $text,
                    autofocusTrigger: autofocusTrigger,
                    pasteTrigger: pasteTrigger,
                    selectAllTrigger: selectAllTrigger
                )
                .overlay(alignment: .topLeading) {
                    if trimmedText.isEmpty {
                        Text("Paste or type your lecture text here")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 38)
                            .padding(.vertical, 42)
                            .allowsHitTesting(false)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .navigationTitle("Text Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                    }
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Button("Paste") {
                        pasteTrigger += 1
                    }
                    .disabled(!UIPasteboard.general.hasStrings)

                    Button("Select All") {
                        selectAllTrigger += 1
                    }
                    .disabled(text.isEmpty)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        submitFeedbackToken += 1
                        submit()
                    } label: {
                        HStack(spacing: 10) {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            }

                            if isSubmitting {
                                Text("Sending...")
                                    .bold()
                            } else {
                                Text("Send")
                                    .bold()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.black)
                    .disabled(trimmedText.isEmpty || isSubmitting)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 12)
                .background(.ultraThinMaterial)
            }
            .onAppear {
                autofocusTrigger += 1
            }
            .sensoryFeedback(.impact(weight: .light), trigger: submitFeedbackToken)
        }
    }

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func submit() {
        guard !trimmedText.isEmpty, !isSubmitting else {
            return
        }

        isSubmitting = true
        errorMessage = nil

        Task {
            let errorMessage = await onSubmit(trimmedText)

            await MainActor.run {
                if let errorMessage {
                    self.errorMessage = errorMessage
                    isSubmitting = false
                }
            }
        }
    }
}

private struct TextImportEditorView: UIViewRepresentable {
    @Binding var text: String
    let autofocusTrigger: Int
    let pasteTrigger: Int
    let selectAllTrigger: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .systemBackground
        textView.textColor = .label
        textView.font = .preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.autocorrectionType = .yes
        textView.autocapitalizationType = .sentences
        textView.smartDashesType = .yes
        textView.smartQuotesType = .yes
        textView.smartInsertDeleteType = .yes
        textView.textContentType = .none
        textView.keyboardDismissMode = .interactive
        textView.textContainerInset = UIEdgeInsets(top: 22, left: 16, bottom: 22, right: 16)
        textView.layer.cornerRadius = 24
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.black.withAlphaComponent(0.05).cgColor
        textView.enablesReturnKeyAutomatically = false
        textView.allowsEditingTextAttributes = false
        textView.inputAssistantItem.leadingBarButtonGroups = []
        textView.inputAssistantItem.trailingBarButtonGroups = []

        context.coordinator.attach(to: textView)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        if textView.text != text {
            textView.text = text
        }

        context.coordinator.attach(to: textView)
        context.coordinator.handleEditorActionTriggers(
            autofocusTrigger: autofocusTrigger,
            pasteTrigger: pasteTrigger,
            selectAllTrigger: selectAllTrigger
        )
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding private var text: String
        private weak var textView: UITextView?
        private var lastAutofocusTrigger = 0
        private var lastPasteTrigger = 0
        private var lastSelectAllTrigger = 0

        init(text: Binding<String>) {
            _text = text
        }

        func attach(to textView: UITextView) {
            self.textView = textView
        }

        func textViewDidChange(_ textView: UITextView) {
            text = textView.text
        }

        func handleEditorActionTriggers(
            autofocusTrigger: Int,
            pasteTrigger: Int,
            selectAllTrigger: Int
        ) {
            guard let textView else {
                return
            }

            if autofocusTrigger != lastAutofocusTrigger {
                lastAutofocusTrigger = autofocusTrigger

                Task { @MainActor [weak textView] in
                    guard let textView, !textView.isFirstResponder else {
                        return
                    }

                    textView.becomeFirstResponder()
                }
            }

            if pasteTrigger != lastPasteTrigger {
                lastPasteTrigger = pasteTrigger
                textView.paste(nil)
            }

            if selectAllTrigger != lastSelectAllTrigger {
                lastSelectAllTrigger = selectAllTrigger
                textView.selectAll(nil)
            }
        }
    }
}

#Preview {
    TextImportSheetView(onClose: {}, onSubmit: { _ in nil })
}
