import SwiftUI

struct LecturesSearchBarView: View {
    @Binding var text: String
    let isSearching: Bool
    let onClear: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search lectures", text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if isSearching {
                    ProgressView()
                        .controlSize(.small)
                } else if !text.isEmpty {
                    Button("Clear", systemImage: "xmark.circle.fill", action: onClear)
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.secondary)
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.primary.opacity(0.06), in: .rect(cornerRadius: 16))

            Button("Cancel", action: onCancel)
                .foregroundStyle(.primary)
                .buttonStyle(.plain)
        }
    }
}
