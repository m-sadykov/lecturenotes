import SwiftUI
import UniformTypeIdentifiers

struct LecturesListView: View {
    @AppStorage("hasConfirmedAIProcessingConsent") private var hasConfirmedAIProcessingConsent = false
    @State var viewModel: LecturesListViewModel
    let repository: LectureRepository
    let processingService: FirebaseLectureProcessingService?
    @State private var selectedLecture: Lecture?
    @State private var activeSheet: ActiveSheet?
    @State private var recorderViewModel: RecorderViewModel?
    @State private var toastMessage: String?
    @State private var removalFeedbackToken = 0
    @State private var importFeedbackToken = 0
    @State private var isImporterPresented = false
    @State private var isTextImportSheetPresented = false
    @State private var isYouTubeImportSheetPresented = false
    @State private var isImportAlertPresented = false
    @State private var importAlertMessage = ""
    @State private var pendingDeletionLecture: Lecture?
    @State private var isAIConsentPresented = false
    @State private var pendingConsentAction: PendingConsentAction?
    @State private var pendingTextImportLecture: Lecture?
    @State private var pendingYouTubeImportLecture: Lecture?

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
                            presentImportFlow()
                        } onImportText: {
                            presentTextImportFlow()
                        } onImportYouTube: {
                            presentYouTubeImportFlow()
                        }
                        
                        RecordingsSectionHeaderView(
                            foldersDestination: FoldersScreen(viewModel: viewModel),
                            showsFoldersNavigation: true
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
                        } else if viewModel.lectures.isEmpty {
                            EmptyLecturesPlaceholderView()
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                        } else if viewModel.filteredLectures.isEmpty, viewModel.selectedFolderID != nil {
                            EmptyFolderPlaceholderView()
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(viewModel.filteredLectures) { lecture in
                                    LectureRowView(
                                        lecture: lecture,
                                        onOpen: {
                                            selectedLecture = lecture
                                        },
                                        onMore: {
                                            activeSheet = .actions(lecture.id)
                                        }
                                    )
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
            .navigationDestination(item: $selectedLecture) { lecture in
                LectureDetailView(
                    lecture: lecture,
                    repository: repository,
                    processingService: processingService,
                    onLectureUpdated: { updatedLecture in
                        viewModel.replaceLecture(updatedLecture)
                        if selectedLecture?.id == updatedLecture.id {
                            selectedLecture = updatedLecture
                        }
                    },
                    onLectureDeleted: { lectureID in
                        let result = await viewModel.deleteLecture(lectureID)

                        switch result {
                        case .deleted:
                            await MainActor.run {
                                if selectedLecture?.id == lectureID {
                                    selectedLecture = nil
                                }
                            }
                            return true
                        case .rejected(let message):
                            await MainActor.run {
                                showToast(message)
                            }
                            return false
                        }
                    }
                )
            }
            .overlay(alignment: .bottomTrailing) {
                if activeSheet == nil && recorderViewModel == nil {
                    FloatingRecordButton {
                        presentRecorderFlow()
                    }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                }
            }
            .overlay {
                if recorderViewModel != nil {
                    Button {
                        recorderViewModel = nil
                    } label: {
                        Color.black.opacity(0.18)
                            .ignoresSafeArea()
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }

                if isAIConsentPresented {
                    Button {
                        isAIConsentPresented = false
                        pendingConsentAction = nil
                    } label: {
                        Color.black.opacity(0.28)
                            .ignoresSafeArea()
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }
            .overlay(alignment: .bottom) {
                if let recorderViewModel {
                    MiniRecorderSheetView(
                        viewModel: recorderViewModel,
                        onSave: { recording in
                            Task {
                                let result = await viewModel.saveRecording(recording)
                                await MainActor.run {
                                    switch result {
                                    case .saved(let savedLecture):
                                        selectedLecture = savedLecture
                                    case .rejected(let message):
                                        showToast(message)
                                    }
                                }
                            }
                        }
                    ) {
                        self.recorderViewModel = nil
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .ignoresSafeArea(edges: .bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if isAIConsentPresented {
                    AIProcessingConsentCard(
                        onCancel: {
                            isAIConsentPresented = false
                            pendingConsentAction = nil
                        },
                        onContinue: {
                            hasConfirmedAIProcessingConsent = true
                            isAIConsentPresented = false
                            switch pendingConsentAction {
                            case .record:
                                recorderViewModel = RecorderViewModel()
                            case .importAudio:
                                isImporterPresented = true
                            case .importText:
                                isTextImportSheetPresented = true
                            case .importYouTube:
                                isYouTubeImportSheetPresented = true
                            case nil:
                                recorderViewModel = RecorderViewModel()
                            }
                            pendingConsentAction = nil
                        }
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 56)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
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
            .animation(.spring(response: 0.32, dampingFraction: 0.88), value: recorderViewModel != nil)
            .sensoryFeedback(.success, trigger: removalFeedbackToken)
            .sensoryFeedback(.impact(weight: .light), trigger: importFeedbackToken)
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
                                pendingDeletionLecture = lecture
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
            .fullScreenCover(
                isPresented: $isTextImportSheetPresented,
                onDismiss: {
                    if let lecture = pendingTextImportLecture {
                        pendingTextImportLecture = nil
                        selectedLecture = lecture
                    }
                }
            ) {
                TextImportSheetView(
                    onClose: {
                        isTextImportSheetPresented = false
                    },
                    onSubmit: { text in
                        let result = await viewModel.importText(text)

                        switch result {
                        case .saved(let lecture):
                            await MainActor.run {
                                importFeedbackToken += 1
                                pendingTextImportLecture = lecture
                                isTextImportSheetPresented = false
                            }
                            return nil
                        case .rejected(let message):
                            return message
                        }
                    }
                )
            }
            .sheet(
                isPresented: $isYouTubeImportSheetPresented,
                onDismiss: {
                    if let lecture = pendingYouTubeImportLecture {
                        pendingYouTubeImportLecture = nil
                        selectedLecture = lecture
                    }
                }
            ) {
                YouTubeImportSheetView(
                    onClose: {
                        isYouTubeImportSheetPresented = false
                    },
                    onSubmit: { urlString in
                        let result = await viewModel.importYouTube(urlString: urlString)

                        switch result {
                        case .saved(let lecture):
                            await MainActor.run {
                                importFeedbackToken += 1
                                pendingYouTubeImportLecture = lecture
                                isYouTubeImportSheetPresented = false
                            }
                            return nil
                        case .rejected(let message):
                            return message
                        }
                    }
                )
                .presentationDetents([.height(240), .medium])
                .presentationDragIndicator(.visible)
            }
            .alert("Import", isPresented: $isImportAlertPresented) {
                Button("OK") {}
            } message: {
                Text(importAlertMessage)
            }
            .alert(
                "Delete Lecture?",
                isPresented: Binding(
                    get: { pendingDeletionLecture != nil },
                    set: { isPresented in
                        if !isPresented {
                            pendingDeletionLecture = nil
                        }
                    }
                ),
                presenting: pendingDeletionLecture
            ) { lecture in
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task {
                        let result = await viewModel.deleteLecture(lecture.id)
                        await MainActor.run {
                            pendingDeletionLecture = nil

                            if case .rejected(let message) = result {
                                importAlertMessage = message
                                isImportAlertPresented = true
                            }
                        }
                    }
                }
            } message: { lecture in
                Text("Delete \"\(lecture.title)\"? This action cannot be undone.")
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

            Task {
                let importResult = await viewModel.importAudio(from: url)

                await MainActor.run {
                    switch importResult {
                    case .saved(let lecture):
                        importFeedbackToken += 1
                        selectedLecture = lecture
                    case .rejected(let message):
                        importAlertMessage = message
                        isImportAlertPresented = true
                    }
                }
            }
        case .failure(let error):
            importAlertMessage = "Import failed: \(error.localizedDescription)"
            isImportAlertPresented = true
        }
    }

    private func presentRecorderFlow() {
        guard processingService != nil else {
            recorderViewModel = RecorderViewModel()
            return
        }

        if hasConfirmedAIProcessingConsent {
            recorderViewModel = RecorderViewModel()
        } else {
            pendingConsentAction = .record
            isAIConsentPresented = true
        }
    }

    private func presentImportFlow() {
        guard processingService != nil else {
            isImporterPresented = true
            return
        }

        if hasConfirmedAIProcessingConsent {
            isImporterPresented = true
        } else {
            pendingConsentAction = .importAudio
            isAIConsentPresented = true
        }
    }

    private func presentTextImportFlow() {
        guard processingService != nil else {
            isTextImportSheetPresented = true
            return
        }

        if hasConfirmedAIProcessingConsent {
            isTextImportSheetPresented = true
        } else {
            pendingConsentAction = .importText
            isAIConsentPresented = true
        }
    }

    private func presentYouTubeImportFlow() {
        guard processingService != nil else {
            isYouTubeImportSheetPresented = true
            return
        }

        if hasConfirmedAIProcessingConsent {
            isYouTubeImportSheetPresented = true
        } else {
            pendingConsentAction = .importYouTube
            isAIConsentPresented = true
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

private struct EmptyLecturesPlaceholderView: View {
    var body: some View {
        ContentUnavailableView {
            Text("No recordings yet")
        } description: {
            Text("Tap the mic button to start recording.")
        }
    }
}

private struct EmptyFolderPlaceholderView: View {
    var body: some View {
        ContentUnavailableView {
            Text("No recordings in this folder")
        } description: {
            Text("Use the menu button on a recording to move it into this folder.")
        }
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

private enum PendingConsentAction {
    case record
    case importAudio
    case importText
    case importYouTube
}

#Preview {
    LecturesListPreviewCanvas()
}

private struct LecturesListPreviewCanvas: View {
    private let lectures = MockLectures.makeLectures()
    private let folders = MockLectures.makeFolders()

    var body: some View {
        VStack(spacing: 0) {
            previewHeader
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PremiumBannerView()
                    QuickActionsStripView {} onImportText: {} onImportYouTube: {}
                    previewSectionHeader
                    previewFolderChips

                    if let firstLecture = lectures.first {
                        LectureRowView(lecture: firstLecture, onOpen: {}, onMore: {})
                    }

                    if lectures.count > 1 {
                        LectureRowView(lecture: lectures[1], onOpen: {}, onMore: {})
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
        }
        .background(Color(.systemGray6))
    }

    private var previewHeader: some View {
        HStack {
            Text("LectureNotes")
                .font(.title)
                .bold()
            Spacer()
            Image(systemName: "gearshape")
                .font(.title3)
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.05))
                .clipShape(.circle)
        }
    }

    private var previewSectionHeader: some View {
        HStack {
            Text("Recordings")
                .font(.title)
                .bold()
            Spacer()
            Image(systemName: "folder")
                .foregroundStyle(.blue.opacity(0.5))
            Button("Search", systemImage: "magnifyingglass") {}
                .labelStyle(.iconOnly)
                .foregroundStyle(.blue)
                .buttonStyle(.plain)
        }
    }

    private var previewFolderChips: some View {
        ScrollView(.horizontal) {
            HStack {
                previewChip(title: "All", isSelected: true)

                if !folders.isEmpty {
                    previewChip(title: folders[0].name, isSelected: false)
                }

                if folders.count > 1 {
                    previewChip(title: folders[1].name, isSelected: false)
                }

                if folders.count > 2 {
                    previewChip(title: folders[2].name, isSelected: false)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func previewChip(title: String, isSelected: Bool) -> some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? .black : .white)
            .clipShape(.rect(cornerRadius: 16))
    }
}
