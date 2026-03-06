import SwiftUI
import UniformTypeIdentifiers

struct LecturesListView: View {
    @State var viewModel: LecturesListViewModel
    @State private var activeSheet: ActiveSheet?
    @State private var toastMessage: String?
    @State private var removalFeedbackToken = 0
    @State private var isImporterPresented = false
    @State private var isImportAlertPresented = false
    @State private var importAlertMessage = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HomeHeaderView()
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
                    .padding(.bottom, 12)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PremiumBannerView()
                        QuickActionsStripView {
                            isImporterPresented = true
                        }
                        RecordingsSectionHeaderView(
                            foldersDestination: FoldersScreen(viewModel: viewModel)
                        )
                        if !viewModel.folders.isEmpty {
                            FolderFilterChipsView(
                                folders: viewModel.folders,
                                selectedFolderID: $viewModel.selectedFolderID
                            )
                        }

                        if viewModel.isLoading {
                            ProgressView("Loading lectures")
                                .frame(maxWidth: .infinity)
                        } else {
                            LazyVStack {
                                ForEach(viewModel.filteredLectures) { lecture in
                                    NavigationLink(value: lecture) {
                                        LectureRowView(lecture: lecture) {
                                            activeSheet = .actions(lecture.id)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
            }
            .background(Color(.systemGray6))
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Lecture.self) { lecture in
                LectureDetailView(lecture: lecture)
            }
            .overlay(alignment: .bottomTrailing) {
                if activeSheet == nil {
                    FloatingRecordButton()
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                }
            }
            .overlay(alignment: .top) {
                if let toastMessage {
                    ToastBannerView(message: toastMessage)
                        .padding(.top, 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: toastMessage != nil)
            .sensoryFeedback(.success, trigger: removalFeedbackToken)
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .actions(let lectureID):
                    if let lecture = viewModel.lecture(withID: lectureID) {
                        RecordingActionsSheet(
                            lecture: lecture,
                            onAddToFolder: {
                                activeSheet = .folderPicker(lectureID)
                            },
                            onRemoveFromFolder: lecture.folderID == nil ? nil : {
                                let folderName = viewModel.removeLectureFromFolder(lectureID)
                                activeSheet = nil
                                removalFeedbackToken += 1
                                showToast(
                                    folderName.map { "Removed from \($0)." } ?? "Removed from folder."
                                )
                            },
                            onEditTitle: {},
                            onShare: {},
                            onDelete: {
                                activeSheet = nil
                            }
                        )
                        .presentationDetents([.height(lecture.folderID == nil ? 290 : 340), .fraction(0.52)])
                    }
                case .folderPicker(let lectureID):
                    if let lecture = viewModel.lecture(withID: lectureID) {
                        FolderSelectionSheet(
                            lecture: lecture,
                            folders: viewModel.folders,
                            selectedFolderID: lecture.folderID,
                            onCreateFolder: { folderName in
                                viewModel.createFolder(named: folderName)
                            },
                            onSelectFolder: { folderID in
                                viewModel.addLecture(lectureID, toFolder: folderID)
                                activeSheet = nil
                            },
                            onClose: {
                                activeSheet = nil
                            }
                        )
                        .presentationDetents([.fraction(0.52), .large])
                    }
                }
            }
            .fileImporter(
                isPresented: $isImporterPresented,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: false
            ) { result in
                handleAudioImport(result)
            }
            .alert("Import Recording", isPresented: $isImportAlertPresented) {
                Button("OK") {}
            } message: {
                Text(importAlertMessage)
            }
            .task {
                await viewModel.load()
            }
        }
    }

    private func showToast(_ message: String) {
        toastMessage = message

        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                guard toastMessage == message else {
                    return
                }
                toastMessage = nil
            }
        }
    }

    private func handleAudioImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                importAlertMessage = "No audio file was selected."
                isImportAlertPresented = true
                return
            }
            importAlertMessage = "Selected: \(url.lastPathComponent)"
            isImportAlertPresented = true
        case .failure(let error):
            importAlertMessage = "Import failed: \(error.localizedDescription)"
            isImportAlertPresented = true
        }
    }
}

private struct ToastBannerView: View {
    let message: String

    var body: some View {
        Text(message)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.black.opacity(0.88))
            .clipShape(.rect(cornerRadius: 14))
            .shadow(radius: 10, y: 4)
    }
}

private enum ActiveSheet: Identifiable {
    case actions(Lecture.ID)
    case folderPicker(Lecture.ID)

    var id: String {
        switch self {
        case .actions(let lectureID):
            "actions-\(lectureID)"
        case .folderPicker(let lectureID):
            "folderPicker-\(lectureID)"
        }
    }
}

#Preview {
    LecturesListView(viewModel: LecturesListViewModel(repository: MockLectureRepository()))
}
