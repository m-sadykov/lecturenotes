import SwiftUI

struct RecordingActionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isDeleteAlertPresented = false

    let lecture: Lecture
    let onAddToFolder: () -> Void
    let onRemoveFromFolder: (() -> Void)?
    let onEditTitle: () -> Void
    let onShare: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading) {
                    lectureTitleView
                    Text(lecture.createdAt, format: LectureFormatters.dayMonthYear)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 16)

                Divider()
                    .padding(.bottom, 8)

                if let onRemoveFromFolder {
                    ActionRowButton(
                        title: "Remove from folder",
                        systemImage: "folder.badge.minus",
                        role: .destructive,
                        action: onRemoveFromFolder
                    )
                } else {
                    ActionRowButton(title: "Add to folder", systemImage: "folder", action: onAddToFolder)
                }
                ActionRowButton(title: "Edit title", systemImage: "pencil", action: onEditTitle)
//                ActionRowButton(title: "Share As", systemImage: "square.and.arrow.up", action: onShare)

                Divider()
                    .padding(.vertical, 8)

                Button("Delete", systemImage: "trash", role: .destructive) {
                    isDeleteAlertPresented = true
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .presentationDragIndicator(.visible)
        .alert("Delete Lecture?", isPresented: $isDeleteAlertPresented) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                dismiss()
                Task {
                    await Task.yield()
                    onDelete()
                }
            }
        } message: {
            Text("Delete \"\(lecture.displayTitle)\"? This action cannot be undone.")
        }
    }

    @ViewBuilder
    private var lectureTitleView: some View {
        if let localizedDisplayTitleKey = lecture.localizedDisplayTitleKey {
            Text(localizedDisplayTitleKey.resource)
                .font(.title2)
                .bold()
        } else {
            Text(lecture.title)
                .font(.title2)
                .bold()
        }
    }
}

private struct ActionRowButton: View {
    let title: LocalizedStringResource
    let systemImage: String
    var role: ButtonRole? = nil
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            HStack {
                Image(systemName: systemImage)
                Text(title)
                Spacer()
                Image(systemName: "chevron.forward")
                    .foregroundStyle(role == .destructive ? .red : .secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .foregroundStyle(role == .destructive ? .red : .primary)
    }
}
